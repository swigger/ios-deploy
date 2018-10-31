#import <Foundation/Foundation.h>
#include "script.h"
#include "zlib.h"

#define LLDB_CMDS_PATH @"/tmp/ios-deploy/fruitstrap-lldb-prep-cmds-%u"

#define LLDB_PREP_CMDS CFSTR("\
platform select remote-ios --sysroot '{symbols_path}'\n\
target create \"{disk_app}\"\n\
script fruitstrap_device_app=\"{device_app}\"\n\
script fruitstrap_connect_url=\"connect://127.0.0.1:{device_port}\"\n\
target modules search-paths add {modules_search_paths_pairs}\n\
command script import \"{python_file_path}\"\n\
command script add -f {python_command}.connect_command connect\n\
command script add -s asynchronous -f {python_command}.run_command run\n\
command script add -s asynchronous -f {python_command}.autoexit_command autoexit\n\
command script add -s asynchronous -f {python_command}.safequit_command safequit\n\
connect\n\
")

struct script_options g_scopt;


CFMutableDataRef inflate_data(const void * data, size_t len)
{
#define BUFSIZE 4096
	Byte outbuf[BUFSIZE];
	z_stream zs;
	memset(&zs, 0, sizeof(zs));
	int err = inflateInit2(&zs, -MAX_WBITS);
	if (err != Z_OK) return NULL;
	CFMutableDataRef dout = CFDataCreateMutable(kCFAllocatorDefault, 0);
	zs.next_in = (Byte*)data;
	zs.avail_in = (uInt) len;
	for (;zs.avail_in;)
	{
		zs.next_out  = outbuf;
		zs.avail_out = sizeof(outbuf);
		err = inflate(&zs, Z_NO_FLUSH);
		if (err == Z_STREAM_END || err == Z_OK)
		{
			CFDataAppendBytes(dout, (unsigned char*)outbuf, BUFSIZE - zs.avail_out);
			if (err == Z_STREAM_END) break;
		}
		else
		{
			on_error(@"zlib error %d", err);
			break;
		}
	}
	inflateEnd(&zs);
	return dout;
}

/*
 * Some things do not seem to work when using the normal commands like process connect/launch, so we invoke them
 * through the python interface. Also, Launch () doesn't seem to work when ran from init_module (), so we add
 * a command which can be used by the user to run it.
 */
#include "lldb.py.h"
static CFMutableStringRef lldb_fruitstrap_module()
{
	size_t len = sizeof(script_py);
	CFMutableDataRef dd = inflate_data(script_py+10, len-10);
	CFStringRef s0 = CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(dd), CFDataGetLength(dd), kCFStringEncodingUTF8, false);
	CFMutableStringRef s1 = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, s0);
	CFRelease(dd);
	CFRelease(s0);
	return s1;
}

CFStringRef copy_modules_search_paths_pairs(CFStringRef symbols_path, CFStringRef disk_container, CFStringRef device_container_private, CFStringRef device_container_noprivate )
{
	CFMutableStringRef res = CFStringCreateMutable(kCFAllocatorDefault, 0);
	CFStringAppendFormat(res, NULL, CFSTR("/usr \"%@/usr\""), symbols_path);
	CFStringAppendFormat(res, NULL, CFSTR(" /System \"%@/System\""), symbols_path);
	CFStringAppendFormat(res, NULL, CFSTR(" \"%@\" \"%@\""), device_container_private, disk_container);
	CFStringAppendFormat(res, NULL, CFSTR(" \"%@\" \"%@\""), device_container_noprivate, disk_container);
	CFStringAppendFormat(res, NULL, CFSTR(" /Developer \"%@/Developer\""), symbols_path);
	return res;
}

void write_lldb_prep_cmds(AMDeviceRef device, CFURLRef disk_app_url)
{
	CFStringRef symbols_path = copy_device_support_path(device, CFSTR("Symbols"));
	CFMutableStringRef cmds = CFStringCreateMutableCopy(NULL, 0, LLDB_PREP_CMDS);
	CFRange range = { 0, CFStringGetLength(cmds) };
	
	CFStringFindAndReplace(cmds, CFSTR("{symbols_path}"), symbols_path, range, 0);
	range.length = CFStringGetLength(cmds);
	
	CFMutableStringRef pmodule = lldb_fruitstrap_module();
	CFRange rangeLLDB = { 0, CFStringGetLength(pmodule) };
	
	CFStringRef exitcode_app_crash_str = CFStringCreateWithFormat(NULL, NULL, CFSTR("%d"), exitcode_app_crash);
	CFStringFindAndReplace(pmodule, CFSTR("{exitcode_app_crash}"), exitcode_app_crash_str, rangeLLDB, 0);
	rangeLLDB.length = CFStringGetLength(pmodule);
	
	CFStringRef detect_deadlock_timeout_str = CFStringCreateWithFormat(NULL, NULL, CFSTR("%d"), g_scopt.detectDeadlockTimeout);
	CFStringFindAndReplace(pmodule, CFSTR("{detect_deadlock_timeout}"), detect_deadlock_timeout_str, rangeLLDB, 0);
	rangeLLDB.length = CFStringGetLength(pmodule);
	
	if (g_scopt.args) {
		CFStringRef cf_args = CFStringCreateWithCString(NULL, g_scopt.args, kCFStringEncodingUTF8);
		CFStringFindAndReplace(cmds, CFSTR("{args}"), cf_args, range, 0);
		rangeLLDB.length = CFStringGetLength(pmodule);
		CFStringFindAndReplace(pmodule, CFSTR("{args}"), cf_args, rangeLLDB, 0);
		
		//printf("write_lldb_prep_cmds:args: [%s][%s]\n", CFStringGetCStringPtr (cmds,kCFStringEncodingMacRoman),
		//    CFStringGetCStringPtr(pmodule, kCFStringEncodingMacRoman));
		CFRelease(cf_args);
	} else {
		CFStringFindAndReplace(cmds, CFSTR("{args}"), CFSTR(""), range, 0);
		CFStringFindAndReplace(pmodule, CFSTR("{args}"), CFSTR(""), rangeLLDB, 0);
		//printf("write_lldb_prep_cmds: [%s][%s]\n", CFStringGetCStringPtr (cmds,kCFStringEncodingMacRoman),
		//    CFStringGetCStringPtr(pmodule, kCFStringEncodingMacRoman));
	}
	range.length = CFStringGetLength(cmds);
	
	CFStringRef bundle_identifier = copy_disk_app_identifier(disk_app_url);
	CFURLRef device_app_url = copy_device_app_url(device, bundle_identifier);
	CFStringRef device_app_path = CFURLCopyFileSystemPath(device_app_url, kCFURLPOSIXPathStyle);
	CFStringFindAndReplace(cmds, CFSTR("{device_app}"), device_app_path, range, 0);
	range.length = CFStringGetLength(cmds);
	
	CFStringRef disk_app_path = CFURLCopyFileSystemPath(disk_app_url, kCFURLPOSIXPathStyle);
	CFStringFindAndReplace(cmds, CFSTR("{disk_app}"), disk_app_path, range, 0);
	range.length = CFStringGetLength(cmds);
	
	CFStringRef device_port = CFStringCreateWithFormat(NULL, NULL, CFSTR("%d"), g_scopt.port);
	CFStringFindAndReplace(cmds, CFSTR("{device_port}"), device_port, range, 0);
	range.length = CFStringGetLength(cmds);
	
	CFURLRef device_container_url = CFURLCreateCopyDeletingLastPathComponent(NULL, device_app_url);
	CFStringRef device_container_path = CFURLCopyFileSystemPath(device_container_url, kCFURLPOSIXPathStyle);
	CFMutableStringRef dcp_noprivate = CFStringCreateMutableCopy(NULL, 0, device_container_path);
	range.length = CFStringGetLength(dcp_noprivate);
	CFStringFindAndReplace(dcp_noprivate, CFSTR("/private/var/"), CFSTR("/var/"), range, 0);
	range.length = CFStringGetLength(cmds);
	CFStringFindAndReplace(cmds, CFSTR("{device_container}"), dcp_noprivate, range, 0);
	range.length = CFStringGetLength(cmds);
	
	CFURLRef disk_container_url = CFURLCreateCopyDeletingLastPathComponent(NULL, disk_app_url);
	CFStringRef disk_container_path = CFURLCopyFileSystemPath(disk_container_url, kCFURLPOSIXPathStyle);
	CFStringFindAndReplace(cmds, CFSTR("{disk_container}"), disk_container_path, range, 0);
	range.length = CFStringGetLength(cmds);
	
	CFStringRef search_paths_pairs = copy_modules_search_paths_pairs(symbols_path, disk_container_path, device_container_path, dcp_noprivate);
	CFStringFindAndReplace(cmds, CFSTR("{modules_search_paths_pairs}"), search_paths_pairs, range, 0);
	range.length = CFStringGetLength(cmds);
	CFRelease(search_paths_pairs);
	
	NSString* python_command = [NSString stringWithFormat:@"fruitstrap_%u", (uint32_t)getpid()];
	NSString* python_file_path = [NSString stringWithFormat:@"/tmp/ios-deploy/%@.py", python_command];
	mkdirp(@"/tmp/ios-deploy/");
	
	CFStringFindAndReplace(cmds, CFSTR("{python_command}"), (CFStringRef)python_command, range, 0);
	range.length = CFStringGetLength(cmds);
	CFStringFindAndReplace(cmds, CFSTR("{python_file_path}"), (CFStringRef)python_file_path, range, 0);
	range.length = CFStringGetLength(cmds);
	
	CFDataRef cmds_data = CFStringCreateExternalRepresentation(NULL, cmds, kCFStringEncodingUTF8, 0);
	NSString* prep_cmds_path = [NSString stringWithFormat:LLDB_CMDS_PATH, (uint32_t)getpid()];
	FILE * fout = fopen([prep_cmds_path UTF8String], "w");
	fwrite(CFDataGetBytePtr(cmds_data), 1, CFDataGetLength(cmds_data), fout);
	// Write additional commands based on mode we're running in
	fwrite(g_scopt.extra_cmds, 1, strlen(g_scopt.extra_cmds), fout);
	fclose(fout);
	
	CFDataRef pmodule_data = CFStringCreateExternalRepresentation(NULL, pmodule, kCFStringEncodingUTF8, 0);
	fout = fopen([python_file_path UTF8String], "w");
	fwrite(CFDataGetBytePtr(pmodule_data), 1, CFDataGetLength(pmodule_data), fout);
	fclose(fout);
	
	g_scopt.lldb_cmd_path = prep_cmds_path;
	
	CFRelease(cmds);
	CFRelease(symbols_path);
	CFRelease(bundle_identifier);
	CFRelease(device_app_url);
	CFRelease(device_app_path);
	CFRelease(disk_app_path);
	CFRelease(device_container_url);
	CFRelease(device_container_path);
	CFRelease(dcp_noprivate);
	CFRelease(disk_container_url);
	CFRelease(disk_container_path);
	CFRelease(cmds_data);
}
