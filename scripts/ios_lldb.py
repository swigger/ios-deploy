import time
import sys
import shlex
import lldb


class DeployDbg(object):
    def __init__(self):
        self.listener = None
        self.detect_deadlock_timeout = 0
        self.exitcode_timeout = 252
        self.exitcode_error = 253
        self.exitcode_app_crash = 254
        self.args = ""
        self.device_app = ''
        self.connect_url = "connect://127.0.0.1:0000"
        self.helper_script = None

    # wait for target_st while state is in [target_st, other_st]
    def wait_state(self, target_st, *other_st):
        events = []
        state = (lldb.process.GetState() or lldb.eStateInvalid)
        rv = True
        while True:
            if state == target_st:
                rv = True
                break
            elif state in other_st:
                event = lldb.SBEvent()
                if self.listener.WaitForEvent(1, event):
                    state = lldb.process.GetStateFromEvent(event)
                    events.append(event)
                else:
                    state = lldb.eStateInvalid
            else:
                rv = False
                break
        for event in events:
            self.listener.AddEvent(event)
        return rv

    def connect(self, debugger):
        print "connecting", self.connect_url
        error = lldb.SBError()

        # We create a new listener here and will use it for both target and the process.
        # It allows us to prevent data races when both our code and internal lldb code
        # try to process STDOUT/STDERR messages
        self.listener = lldb.SBListener('iosdeploy_listener')

        self.listener.StartListeningForEventClass(
            debugger,
            lldb.SBTarget.GetBroadcasterClassName(),
            lldb.SBProcess.eBroadcastBitStateChanged |
            lldb.SBProcess.eBroadcastBitSTDOUT | lldb.SBProcess.eBroadcastBitSTDERR
        )

        process = lldb.target.ConnectRemote(self.listener, self.connect_url, None, error)
        print "state::::", process.GetState()
        self.wait_state(lldb.eStateConnected, lldb.eStateUnloaded, lldb.eStateInvalid)
        time.sleep(0.05)

    def wait_stop(self):
        self.wait_state(lldb.eStateStopped, lldb.eStateRunning, lldb.eStateStepping)

    def run(self, debugger, command):
        lldb.target.modules[0].SetPlatformFileSpec(lldb.SBFileSpec(self.device_app))
        args = command.split('--', 1)
        error = lldb.SBError()
        args_arr = []
        if len(args) > 1:
            args_arr = shlex.split(args[1], posix=False)
        args_arr = args_arr + shlex.split(self.args, posix=False)

        launchInfo = lldb.SBLaunchInfo(args_arr)
        launchInfo.SetListener(self.listener)
        if self.helper_script:
            launchInfo.SetLaunchFlags(lldb.eLaunchFlagStopAtEntry | lldb.eLaunchFlagDisableASLR)

        # This env variable makes NSLog, CFLog and os_log messages get mirrored to stderr
        # https://stackoverflow.com/a/39581193
        launchInfo.SetEnvironmentEntries(['OS_ACTIVITY_DT_MODE=enable'], True)

        lldb.target.Launch(launchInfo, error)
        lockedstr = ': Locked'
        if lockedstr in str(error):
            print '\\nDevice Locked\\n'
            sys.exit(254)
        else:
            print "Start Status:", str(error)
        # it seems status not sync-ed without this sleep
        time.sleep(0.3)

    def safequit(self):
        process = lldb.target.process
        state = process.GetState()
        if state == lldb.eStateRunning:
            process.Detach()
            sys.exit(0)
        elif state > lldb.eStateRunning:
            sys.exit(state)
        else:
            print('\\nApplication has not been launched\\n')
            sys.exit(1)

    def autoexit(self, debugger):
        process = lldb.target.process

        detectDeadlockTimeout = self.detect_deadlock_timeout
        printBacktraceTime = time.time() + detectDeadlockTimeout if detectDeadlockTimeout > 0 else None

        # This line prevents internal lldb listener from processing STDOUT/STDERR messages.
        #  Without it, an order of log writes is incorrect sometimes
        outev = lldb.SBProcess.eBroadcastBitSTDOUT | lldb.SBProcess.eBroadcastBitSTDERR
        debugger.GetListener().StopListeningForEvents(process.GetBroadcaster(), outev)

        event = lldb.SBEvent()

        def ProcessSTDOUT():
            stdout = process.GetSTDOUT(1024)
            while stdout:
                sys.stdout.write(stdout)
                stdout = process.GetSTDOUT(1024)

        def ProcessSTDERR():
            stderr = process.GetSTDERR(1024)
            while stderr:
                sys.stdout.write(stderr)
                stderr = process.GetSTDERR(1024)

        while True:
            if self.listener.WaitForEvent(1, event) and lldb.SBProcess.EventIsProcessEvent(event):
                state = lldb.SBProcess.GetStateFromEvent(event)
                etype = event.GetType()

                if etype & lldb.SBProcess.eBroadcastBitSTDOUT:
                    ProcessSTDOUT()

                if etype & lldb.SBProcess.eBroadcastBitSTDERR:
                    ProcessSTDERR()

            else:
                state = process.GetState()

            if state != lldb.eStateRunning:
                # Let's make sure that we drained our streams before exit
                ProcessSTDOUT()
                ProcessSTDERR()

            if state == lldb.eStateExited:
                sys.stdout.write('\\nPROCESS_EXITED\\n')
                sys.exit(process.GetExitStatus())
            elif printBacktraceTime is None and state == lldb.eStateStopped:
                sys.stdout.write('\\nPROCESS_STOPPED\\n')
                debugger.HandleCommand('bt')
                sys.exit(self.exitcode_app_crash)
            elif state == lldb.eStateCrashed:
                sys.stdout.write('\\nPROCESS_CRASHED\\n')
                debugger.HandleCommand('bt')
                sys.exit(self.exitcode_app_crash)
            elif state == lldb.eStateDetached:
                sys.stdout.write('\\nPROCESS_DETACHED\\n')
                sys.exit(self.exitcode_app_crash)
            elif printBacktraceTime is not None and time.time() >= printBacktraceTime:
                printBacktraceTime = None
                sys.stdout.write('\\nPRINT_BACKTRACE_TIMEOUT\\n')
                debugger.HandleCommand('process interrupt')
                debugger.HandleCommand('bt all')
                debugger.HandleCommand('continue')
                printBacktraceTime = time.time() + 5


g_opts = DeployDbg()


def init(device_app, port, args, deadto):
    global g_opts
    g_opts.device_app = device_app
    g_opts.connect_url = "connect://127.0.0.1:%d" % port
    g_opts.args = args
    g_opts.detect_deadlock_timeout = deadto


def connect_command(debugger, command, result, internal_dict):
    global g_opts
    g_opts.connect(debugger)


def run_command(debugger, command, result, internal_dict):
    global g_opts
    g_opts.run(debugger, command)


def safequit_command(debugger, command, result, internal_dict):
    global g_opts
    g_opts.safequit()


def check_stop_entry(debugger):
    print lldb.process
    bc = lldb.process.GetBroadcaster()
    lis = lldb.SBListener('my stop listener')
    rc = bc.AddListener(lis, lldb.SBProcess.eBroadcastBitStateChanged)
    #rc is now granted events. should not be 0
    print rc
    event = lldb.SBEvent()
    found_stop = False
    time.sleep(0.1)
    st = None
    for _ in range(0,3):
        st = lldb.process.GetState()
        if st == lldb.eStateStopped:
            break
        if st == lldb.eStateRunning:
            print "Running..."
            break
        if st == lldb.eStateAttaching or st == lldb.eStateLaunching:
            pass
        if not lis.WaitForEventForBroadcasterWithType(1, bc, lldb.SBProcess.eBroadcastBitStateChanged |
                                                               lldb.SBProcess.eBroadcastBitInterrupt, event):
            break
    if st == lldb.eStateStopped:
        debugger.HandleCommand("x/i $pc")
    bc.RemoveListener(lis)


def autoexit_command(debugger, command, result, internal_dict):
    global g_opts
    g_opts.autoexit(debugger)
