#import <Foundation/Foundation.h>
#include "script.h"
#include "zlib.h"
#include <map>
#include <string>
using std::string;
using std::map;

const char * lldb_prep_cmds =
"platform select remote-ios --sysroot '{symbols_path}'\n"
"target create '{disk_app}'\n"
"target modules search-paths add {modules_search_paths_pairs}\n"
"command script import '{python_file_path}'\n"
"script {python_command}.init(\"{device_app}\", {device_port}, \"{args}\", {detect_deadlock_timeout})\n"
"command script add -f {python_command}.connect_command connect\n"
"command script add -s asynchronous -f {python_command}.run_command run\n"
"command script add -s asynchronous -f {python_command}.autoexit_command autoexit\n"
"command script add -s asynchronous -f {python_command}.safequit_command safequit\n"
"connect\n"
;


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
static string lldb_fruitstrap_module()
{
	size_t len = sizeof(script_py);
	CFMutableDataRef dd = inflate_data(script_py+10, len-10);
	string rr = string((char*)CFDataGetBytePtr(dd), CFDataGetLength(dd));
	CFRelease(dd);
	return rr;
}

static CFStringRef copy_modules_search_paths_pairs(CFStringRef symbols_path, CFStringRef disk_container, CFStringRef device_container_private, CFStringRef device_container_noprivate )
{
	CFMutableStringRef res = CFStringCreateMutable(kCFAllocatorDefault, 0);
	CFStringAppendFormat(res, NULL, CFSTR("/usr \"%@/usr\""), symbols_path);
	CFStringAppendFormat(res, NULL, CFSTR(" /System \"%@/System\""), symbols_path);
	CFStringAppendFormat(res, NULL, CFSTR(" \"%@\" \"%@\""), device_container_private, disk_container);
	CFStringAppendFormat(res, NULL, CFSTR(" \"%@\" \"%@\""), device_container_noprivate, disk_container);
	CFStringAppendFormat(res, NULL, CFSTR(" /Developer \"%@/Developer\""), symbols_path);
	return res;
}

static string mkstr(CFStringRef s0, bool free_ = true)
{
	const char * p = CFStringGetCStringPtr(s0, kCFStringEncodingUTF8);
	size_t len = CFStringGetLength(s0);
	string r(p, len);
	if (free_)
		CFRelease(s0);
	return r;
}
static string mkstr(int arg)
{
	char buf[100];
	sprintf(buf, "%d", arg);
	return buf;
}
static string mkstrf(const char * fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	char * outs = 0;
	vasprintf(&outs, fmt, ap);
	string rr = outs;
	free(outs);
	va_end(ap);
	return rr;
}
static void strip_private(string & s)
{
	const char * ptn = "/private/var/";
	if (strncmp(s.c_str(), ptn, strlen(ptn)) == 0)
	{
		s.erase(s.begin(), s.begin() + strlen("/private"));
	}
}

void replaceAll(std::string& source, const std::string& from, const std::string& to)
{
	std::string newString;
	newString.reserve(source.length());  // avoids a few memory allocations
	
	std::string::size_type lastPos = 0;
	std::string::size_type findPos;
	
	while(std::string::npos != (findPos = source.find(from, lastPos)))
	{
		newString.append(source, lastPos, findPos - lastPos);
		newString += to;
		lastPos = findPos + from.length();
	}
	
	// Care for the rest after last occurrence
	newString += source.substr(lastPos);
	source.swap(newString);
}

static void add_helper_script(string & content)
{
	if (!g_scopt.helper_script) return;
	size_t pos = content.find("\nconnect");
	if (pos == string::npos) return;
	const char * sc = "\n"
		"script {python_command}.g_opts.set_helper_script(\"{helper_script}\")\n"
		"connect\n"
		"run\n"
		"script {python_command}.g_opts.wait_stop()\n"
		"command script import \"{helper_script}\"\n";
	replaceAll(content, "\nconnect\nrun\n", sc);
}

static void rm_prep_cmds_file(void)
{
	string prep_cmd_path = mkstrf("/tmp/ios-deploy/fruitstrap-lldb-prep-cmds-%u", (uint32_t)getpid());
	unlink(prep_cmd_path.c_str());
}

void write_lldb_prep_cmds(AMDeviceRef device, CFURLRef disk_app_url)
{
	const char * python_cmd = "ios_deploy";
	CFStringRef bundle_identifier = copy_disk_app_identifier(disk_app_url);
	CFURLRef device_app_url = copy_device_app_url(device, bundle_identifier);
	CFURLRef device_container_url = CFURLCreateCopyDeletingLastPathComponent(NULL, device_app_url);
	CFURLRef disk_container_url = CFURLCreateCopyDeletingLastPathComponent(NULL, disk_app_url);
	
	map<string,string> nvs;
	nvs["symbols_path"] = mkstr(copy_device_support_path(device, CFSTR("Symbols")));
	nvs["args"] = g_scopt.args ? g_scopt.args : "";
	nvs["device_app"] = mkstr(CFURLCopyFileSystemPath(device_app_url, kCFURLPOSIXPathStyle));
	nvs["disk_app"] = mkstr(CFURLCopyFileSystemPath(disk_app_url, kCFURLPOSIXPathStyle));
	nvs["device_port"] = mkstr(g_scopt.port);
	nvs["detect_deadlock_timeout"] = mkstr(g_scopt.detectDeadlockTimeout);
	nvs["device_container"] = mkstr(CFURLCopyFileSystemPath(device_container_url, kCFURLPOSIXPathStyle));
	nvs["disk_container"] = mkstr(CFURLCopyFileSystemPath(disk_container_url, kCFURLPOSIXPathStyle));
	nvs["helper_script"] = g_scopt.helper_script ? g_scopt.helper_script : "";
	
	string search_paths;
	search_paths  = mkstrf("/usr \"%s/usr\" ", nvs["symbols_path"].c_str());
	search_paths += mkstrf("/System \"%s/System\" ", nvs["symbols_path"].c_str());
	search_paths += mkstrf("/Developer \"%s/Developer\" ", nvs["symbols_path"].c_str());
	search_paths += mkstrf("%s \"%s\" ", nvs["device_container"].c_str(), nvs["disk_container"].c_str());
	strip_private(nvs["device_container"]);
	search_paths += mkstrf("%s \"%s\" ", nvs["device_container"].c_str(), nvs["disk_container"].c_str());
	
	nvs["modules_search_paths_pairs"] = search_paths;
	nvs["python_command"] = python_cmd;
	nvs["python_file_path"] = mkstrf("/tmp/ios-deploy/%s.py", python_cmd);
	mkdirp(@"/tmp/ios-deploy/");
	
	string prep_cmd_path = mkstrf("/tmp/ios-deploy/fruitstrap-lldb-prep-cmds-%u", (uint32_t)getpid());
	string pymodule = lldb_fruitstrap_module();
	string prep_content = ::lldb_prep_cmds;
	prep_content += g_scopt.extra_cmds;
	add_helper_script(prep_content);

	//TODO: replace with on-time pass.
	for (auto & p : nvs)
	{
		string key;
		key.reserve(p.first.length()+2);
		key += "{";
		key += p.first;
		key += "}";
		replaceAll(prep_content, key, p.second);
	}
	
	const char * pyfp = nvs["python_file_path"].c_str();
	if (access(pyfp, R_OK) < 0)
	{
		FILE * fout = fopen(pyfp, "wb");
		if (!fout)
			on_sys_error(@"fopen %s failed", pyfp);
		fwrite(pymodule.data(), 1, pymodule.length(), fout);
		fclose(fout);
	}
	{
		FILE * fout = fopen(prep_cmd_path.c_str(), "wb");
		if (!fout)
			on_sys_error(@"fopen %s failed", prep_cmd_path.c_str());
		fwrite(prep_content.data(), 1, prep_content.length(), fout);
		fclose(fout);
	}
	g_scopt.lldb_cmd_path = [NSString stringWithUTF8String: prep_cmd_path.c_str()];
	
	CFRelease(bundle_identifier);
	CFRelease(device_app_url);
	CFRelease(device_container_url);
	CFRelease(disk_container_url);
	
	atexit(rm_prep_cmds_file);
}
