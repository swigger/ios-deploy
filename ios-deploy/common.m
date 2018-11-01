#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <pwd.h>
#include <uuid/uuid.h>
#include "common.h"

void on_error(NSString* format, ...)
{
	va_list valist;
	va_start(valist, format);
	NSString* str = [[NSString alloc] initWithFormat:format arguments:valist];
	va_end(valist);
	
	NSLog(@"[ !! ] %@", str);
	
	exit(exitcode_error);
}

// Print error message getting last errno and exit
void on_sys_error(NSString* format, ...)
{
	const char* errstr = strerror(errno);
	
	va_list valist;
	va_start(valist, format);
	NSString* str = [[NSString alloc] initWithFormat:format arguments:valist];
	va_end(valist);
	
	on_error(@"%@ : %@", str, [NSString stringWithUTF8String:errstr]);
}

int g_log_level = 0;
static void __NSLogOut(NSString* format, va_list valist)
{
	NSString* str = [[NSString alloc] initWithFormat:format arguments:valist];
	fprintf(stdout, "%s\n", [str UTF8String]);
}

void NSLogOut(NSString* format, ...) {
	va_list valist;
	va_start(valist, format);
	__NSLogOut(format, valist);
	va_end(valist);
}
void NSLogVerbose(NSString* format, ...) {
	if (g_log_level >= 1)
	{
		va_list valist;
		va_start(valist, format);
		__NSLogOut(format, valist);
		va_end(valist);
	}
}

#define ADD_DEVICE(model, name, sdk, arch) {CFSTR(model), CFSTR(name), CFSTR(sdk), CFSTR(arch)}

#define UNKNOWN_DEVICE_IDX 0
device_desc device_db[] = {
	ADD_DEVICE("UNKN",   "Unknown Device",             "uknownos", "unkarch"),
	
	// iPod Touch
	ADD_DEVICE("N45AP",  "iPod Touch",                 "iphoneos", "armv7"),
	ADD_DEVICE("N72AP",  "iPod Touch 2G",              "iphoneos", "armv7"),
	ADD_DEVICE("N18AP",  "iPod Touch 3G",              "iphoneos", "armv7"),
	ADD_DEVICE("N81AP",  "iPod Touch 4G",              "iphoneos", "armv7"),
	ADD_DEVICE("N78AP",  "iPod Touch 5G",              "iphoneos", "armv7"),
	ADD_DEVICE("N78AAP", "iPod Touch 5G",              "iphoneos", "armv7"),
	ADD_DEVICE("N102AP", "iPod Touch 6G",              "iphoneos", "arm64"),
	
	// iPad
	ADD_DEVICE("K48AP",  "iPad",                       "iphoneos", "armv7"),
	ADD_DEVICE("K93AP",  "iPad 2",                     "iphoneos", "armv7"),
	ADD_DEVICE("K94AP",  "iPad 2 (GSM)",               "iphoneos", "armv7"),
	ADD_DEVICE("K95AP",  "iPad 2 (CDMA)",              "iphoneos", "armv7"),
	ADD_DEVICE("K93AAP", "iPad 2 (Wi-Fi, revision A)", "iphoneos", "armv7"),
	ADD_DEVICE("J1AP",   "iPad 3",                     "iphoneos", "armv7"),
	ADD_DEVICE("J2AP",   "iPad 3 (GSM)",               "iphoneos", "armv7"),
	ADD_DEVICE("J2AAP",  "iPad 3 (CDMA)",              "iphoneos", "armv7"),
	ADD_DEVICE("P101AP", "iPad 4",                     "iphoneos", "armv7s"),
	ADD_DEVICE("P102AP", "iPad 4 (GSM)",               "iphoneos", "armv7s"),
	ADD_DEVICE("P103AP", "iPad 4 (CDMA)",              "iphoneos", "armv7s"),
	ADD_DEVICE("J71AP",  "iPad Air",                   "iphoneos", "arm64"),
	ADD_DEVICE("J72AP",  "iPad Air (GSM)",             "iphoneos", "arm64"),
	ADD_DEVICE("J73AP",  "iPad Air (CDMA)",            "iphoneos", "arm64"),
	ADD_DEVICE("J81AP",  "iPad Air 2",                 "iphoneos", "arm64"),
	ADD_DEVICE("J82AP",  "iPad Air 2 (GSM)",           "iphoneos", "arm64"),
	ADD_DEVICE("J83AP",  "iPad Air 2 (CDMA)",          "iphoneos", "arm64"),
	ADD_DEVICE("J71sAP", "iPad (2017)",                "iphoneos", "arm64"),
	ADD_DEVICE("J71tAP", "iPad (2017)",                "iphoneos", "arm64"),
	ADD_DEVICE("J72sAP", "iPad (2017)",                "iphoneos", "arm64"),
	ADD_DEVICE("J72tAP", "iPad (2017)",                "iphoneos", "arm64"),
	
	// iPad Pro
	
	ADD_DEVICE("J98aAP",  "iPad Pro (12.9\")",         "iphoneos", "arm64"),
	ADD_DEVICE("J99aAP",  "iPad Pro (12.9\")",         "iphoneos", "arm64"),
	ADD_DEVICE("J120AP",  "iPad Pro 2G (12.9\")",      "iphoneos", "arm64"),
	ADD_DEVICE("J121AP",  "iPad Pro 2G (12.9\")",      "iphoneos", "arm64"),
	ADD_DEVICE("J127AP",  "iPad Pro (9.7\")",          "iphoneos", "arm64"),
	ADD_DEVICE("J128AP",  "iPad Pro (9.7\")",          "iphoneos", "arm64"),
	ADD_DEVICE("J207AP",  "iPad Pro (10.5\")",         "iphoneos", "arm64"),
	ADD_DEVICE("J208AP",  "iPad Pro (10.5\")",         "iphoneos", "arm64"),
	
	// iPad Mini
	
	ADD_DEVICE("P105AP", "iPad mini",                  "iphoneos", "armv7"),
	ADD_DEVICE("P106AP", "iPad mini (GSM)",            "iphoneos", "armv7"),
	ADD_DEVICE("P107AP", "iPad mini (CDMA)",           "iphoneos", "armv7"),
	ADD_DEVICE("J85AP",  "iPad mini 2",                "iphoneos", "arm64"),
	ADD_DEVICE("J86AP",  "iPad mini 2 (GSM)",          "iphoneos", "arm64"),
	ADD_DEVICE("J87AP",  "iPad mini 2 (CDMA)",         "iphoneos", "arm64"),
	ADD_DEVICE("J85MAP", "iPad mini 3",                "iphoneos", "arm64"),
	ADD_DEVICE("J86MAP", "iPad mini 3 (GSM)",          "iphoneos", "arm64"),
	ADD_DEVICE("J87MAP", "iPad mini 3 (CDMA)",         "iphoneos", "arm64"),
	ADD_DEVICE("J96AP",  "iPad mini 4",                "iphoneos", "arm64"),
	ADD_DEVICE("J97AP",  "iPad mini 4 (GSM)",          "iphoneos", "arm64"),
	
	// iPhone
	
	ADD_DEVICE("M68AP",  "iPhone",                     "iphoneos", "armv7"),
	ADD_DEVICE("N82AP",  "iPhone 3G",                  "iphoneos", "armv7"),
	ADD_DEVICE("N88AP",  "iPhone 3GS",                 "iphoneos", "armv7"),
	ADD_DEVICE("N90AP",  "iPhone 4 (GSM)",             "iphoneos", "armv7"),
	ADD_DEVICE("N92AP",  "iPhone 4 (CDMA)",            "iphoneos", "armv7"),
	ADD_DEVICE("N90BAP", "iPhone 4 (GSM, revision A)", "iphoneos", "armv7"),
	ADD_DEVICE("N94AP",  "iPhone 4S",                  "iphoneos", "armv7"),
	ADD_DEVICE("N41AP",  "iPhone 5 (GSM)",             "iphoneos", "armv7s"),
	ADD_DEVICE("N42AP",  "iPhone 5 (Global/CDMA)",     "iphoneos", "armv7s"),
	ADD_DEVICE("N48AP",  "iPhone 5c (GSM)",            "iphoneos", "armv7s"),
	ADD_DEVICE("N49AP",  "iPhone 5c (Global/CDMA)",    "iphoneos", "armv7s"),
	ADD_DEVICE("N51AP",  "iPhone 5s (GSM)",            "iphoneos", "arm64"),
	ADD_DEVICE("N53AP",  "iPhone 5s (Global/CDMA)",    "iphoneos", "arm64"),
	ADD_DEVICE("N61AP",  "iPhone 6 (GSM)",             "iphoneos", "arm64"),
	ADD_DEVICE("N56AP",  "iPhone 6 Plus",              "iphoneos", "arm64"),
	ADD_DEVICE("N71mAP", "iPhone 6s",                  "iphoneos", "arm64"),
	ADD_DEVICE("N71AP",  "iPhone 6s",                  "iphoneos", "arm64"),
	ADD_DEVICE("N66AP",  "iPhone 6s Plus",             "iphoneos", "arm64"),
	ADD_DEVICE("N66mAP", "iPhone 6s Plus",             "iphoneos", "arm64"),
	ADD_DEVICE("N69AP",  "iPhone SE",                  "iphoneos", "arm64"),
	ADD_DEVICE("N69uAP", "iPhone SE",                  "iphoneos", "arm64"),
	ADD_DEVICE("D10AP",  "iPhone 7",                   "iphoneos", "arm64"),
	ADD_DEVICE("D101AP", "iPhone 7",                   "iphoneos", "arm64"),
	ADD_DEVICE("D11AP",  "iPhone 7 Plus",              "iphoneos", "arm64"),
	ADD_DEVICE("D111AP", "iPhone 7 Plus",              "iphoneos", "arm64"),
	ADD_DEVICE("D22AP",  "iPhone X",                   "iphoneos", "arm64"),
	
	// Apple TV
	
	ADD_DEVICE("K66AP",  "Apple TV 2G",                "appletvos", "armv7"),
	ADD_DEVICE("J33AP",  "Apple TV 3G",                "appletvos", "armv7"),
	ADD_DEVICE("J33IAP", "Apple TV 3.1G",              "appletvos", "armv7"),
	ADD_DEVICE("J42dAP", "Apple TV 4G",                "appletvos", "arm64"),
};

device_desc get_device_desc(CFStringRef model)
{
	if (model != NULL)
	{
		size_t sz = sizeof(device_db) / sizeof(device_desc);
		for (size_t i = 0; i < sz; i ++) {
			if (CFStringCompare(model, device_db[i].model, kCFCompareNonliteral | kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
				return device_db[i];
			}
		}
	}
	device_desc res = device_db[UNKNOWN_DEVICE_IDX];
	res.model = model;
	res.name = model;
	return res;
}

BOOL mkdirp(NSString* path)
{
	NSError* error = nil;
	BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:path
											 withIntermediateDirectories:YES
															  attributes:nil
																   error:&error];
	return success;
}

CFStringRef copy_xcode_dev_path() {
	static char xcode_dev_path[256] = { '\0' };
	if (strlen(xcode_dev_path) == 0) {
		FILE *fpipe = NULL;
		char *command = "xcode-select -print-path";
		
		if (!(fpipe = (FILE *)popen(command, "r")))
			on_sys_error(@"Error encountered while opening pipe");
		
		char buffer[256] = { '\0' };
		
		fgets(buffer, sizeof(buffer), fpipe);
		pclose(fpipe);
		
		strtok(buffer, "\n");
		strcpy(xcode_dev_path, buffer);
	}
	return CFStringCreateWithCString(NULL, xcode_dev_path, kCFStringEncodingUTF8);
}

const char *get_home() {
	const char* home = getenv("HOME");
	if (!home) {
		struct passwd *pwd = getpwuid(getuid());
		home = pwd->pw_dir;
	}
	return home;
}

Boolean path_exists(CFTypeRef path) {
	if (CFGetTypeID(path) == CFStringGetTypeID()) {
		CFURLRef url = CFURLCreateWithFileSystemPath(NULL, path, kCFURLPOSIXPathStyle, true);
		Boolean result = CFURLResourceIsReachable(url, NULL);
		CFRelease(url);
		return result;
	} else if (CFGetTypeID(path) == CFURLGetTypeID()) {
		return CFURLResourceIsReachable(path, NULL);
	} else {
		return false;
	}
}

CFStringRef find_path(CFStringRef rootPath, CFStringRef namePattern) {
	FILE *fpipe = NULL;
	CFStringRef cf_command;
	
	if( !path_exists(rootPath) )
		return NULL;
	
	if (CFStringFind(namePattern, CFSTR("*"), 0).location == kCFNotFound) {
		//No wildcards. Let's speed up the search
		CFStringRef path = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/%@"), rootPath, namePattern);
		
		if( path_exists(path) )
			return path;
		
		CFRelease(path);
		return NULL;
	}
	
	if (CFStringFind(namePattern, CFSTR("/"), 0).location == kCFNotFound) {
		cf_command = CFStringCreateWithFormat(NULL, NULL, CFSTR("find '%@' -name '%@' -maxdepth 1 2>/dev/null | sort | tail -n 1"), rootPath, namePattern);
	} else {
		cf_command = CFStringCreateWithFormat(NULL, NULL, CFSTR("find '%@' -path '%@/%@' 2>/dev/null | sort | tail -n 1"), rootPath, rootPath, namePattern);
	}
	
	char command[1024] = { '\0' };
	CFStringGetCString(cf_command, command, sizeof(command), kCFStringEncodingUTF8);
	CFRelease(cf_command);
	
	if (!(fpipe = (FILE *)popen(command, "r")))
		on_sys_error(@"Error encountered while opening pipe");
	
	char buffer[256] = { '\0' };
	
	fgets(buffer, sizeof(buffer), fpipe);
	pclose(fpipe);
	
	strtok(buffer, "\n");
	
	CFStringRef path = CFStringCreateWithCString(NULL, buffer, kCFStringEncodingUTF8);
	
	if( CFStringGetLength(path) > 0 && path_exists(path) )
		return path;
	
	CFRelease(path);
	return NULL;
}

CFStringRef copy_xcode_path_for_impl(CFStringRef rootPath, CFStringRef subPath, CFStringRef search) {
	CFStringRef searchPath = CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/%@"), rootPath, subPath );
	CFStringRef res = find_path(searchPath, search);
	CFRelease(searchPath);
	return res;
}

CFStringRef copy_xcode_path_for(CFStringRef subPath, CFStringRef search) {
	CFStringRef xcodeDevPath = copy_xcode_dev_path();
	CFStringRef defaultXcodeDevPath = CFSTR("/Applications/Xcode.app/Contents/Developer");
	CFStringRef path = NULL;
	const char* home = get_home();
	
	// Try using xcode-select --print-path
	path = copy_xcode_path_for_impl(xcodeDevPath, subPath, search);
	
	// If not look in the default xcode location (xcode-select is sometimes wrong)
	if (path == NULL && CFStringCompare(xcodeDevPath, defaultXcodeDevPath, 0) != kCFCompareEqualTo )
		path = copy_xcode_path_for_impl(defaultXcodeDevPath, subPath, search);
	
	// If not look in the users home directory, Xcode can store device support stuff there
	if (path == NULL) {
		CFRelease(xcodeDevPath);
		xcodeDevPath = CFStringCreateWithFormat(NULL, NULL, CFSTR("%s/Library/Developer/Xcode"), home );
		path = copy_xcode_path_for_impl(xcodeDevPath, subPath, search);
	}
	
	CFRelease(xcodeDevPath);
	
	return path;
}

CFURLRef copy_device_app_url(AMDeviceRef device, CFStringRef identifier) {
	CFDictionaryRef result = nil;
	
	NSArray *a = [NSArray arrayWithObjects:
				  @"CFBundleIdentifier",            // absolute must
				  @"ApplicationDSID",
				  @"ApplicationType",
				  @"CFBundleExecutable",
				  @"CFBundleDisplayName",
				  @"CFBundleIconFile",
				  @"CFBundleName",
				  @"CFBundleShortVersionString",
				  @"CFBundleSupportedPlatforms",
				  @"CFBundleURLTypes",
				  @"CodeInfoIdentifier",
				  @"Container",
				  @"Entitlements",
				  @"HasSettingsBundle",
				  @"IsUpgradeable",
				  @"MinimumOSVersion",
				  @"Path",
				  @"SignerIdentity",
				  @"UIDeviceFamily",
				  @"UIFileSharingEnabled",
				  @"UIStatusBarHidden",
				  @"UISupportedInterfaceOrientations",
				  nil];
	
	NSDictionary *optionsDict = [NSDictionary dictionaryWithObject:a forKey:@"ReturnAttributes"];
	CFDictionaryRef options = (__bridge CFDictionaryRef)optionsDict;
	
	check_error(AMDeviceLookupApplications(device, options, &result));
	
	CFDictionaryRef app_dict = CFDictionaryGetValue(result, identifier);
	assert(app_dict != NULL);
	
	CFStringRef app_path = CFDictionaryGetValue(app_dict, CFSTR("Path"));
	assert(app_path != NULL);
	
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL, app_path, kCFURLPOSIXPathStyle, true);
	CFRelease(result);
	return url;
}

CFStringRef copy_disk_app_identifier(CFURLRef disk_app_url) {
	CFURLRef plist_url = CFURLCreateCopyAppendingPathComponent(NULL, disk_app_url, CFSTR("Info.plist"), false);
	CFReadStreamRef plist_stream = CFReadStreamCreateWithFile(NULL, plist_url);
	if (!CFReadStreamOpen(plist_stream)) {
		on_error(@"Cannot read Info.plist file: %@", plist_url);
	}
	
	CFPropertyListRef plist = CFPropertyListCreateWithStream(NULL, plist_stream, 0, kCFPropertyListImmutable, NULL, NULL);
	CFStringRef bundle_identifier = CFRetain(CFDictionaryGetValue(plist, CFSTR("CFBundleIdentifier")));
	CFReadStreamClose(plist_stream);
	
	CFRelease(plist_url);
	CFRelease(plist_stream);
	CFRelease(plist);
	
	return bundle_identifier;
}

CFMutableArrayRef get_device_product_version_parts(AMDeviceRef device) {
	CFStringRef version = AMDeviceCopyValue(device, 0, CFSTR("ProductVersion"));
	CFArrayRef parts = CFStringCreateArrayBySeparatingStrings(NULL, version, CFSTR("."));
	CFMutableArrayRef result = CFArrayCreateMutableCopy(NULL, CFArrayGetCount(parts), parts);
	CFRelease(version);
	CFRelease(parts);
	return result;
}


CFStringRef copy_device_support_path(AMDeviceRef device, CFStringRef suffix) {
	time_t startTime, endTime;
	time( &startTime );
	
	CFStringRef version = NULL;
	CFStringRef build = AMDeviceCopyValue(device, 0, CFSTR("BuildVersion"));
	CFStringRef deviceClass = AMDeviceCopyValue(device, 0, CFSTR("DeviceClass"));
	CFStringRef path = NULL;
	CFMutableArrayRef version_parts = get_device_product_version_parts(device);
	
	NSLogVerbose(@"Device Class: %@", deviceClass);
	NSLogVerbose(@"build: %@", build);
	
	CFStringRef deviceClassPath[2];
	
	if (CFStringCompare(CFSTR("AppleTV"), deviceClass, 0) == kCFCompareEqualTo) {
		deviceClassPath[0] = CFSTR("Platforms/AppleTVOS.platform/DeviceSupport");
		deviceClassPath[1] = CFSTR("tvOS DeviceSupport");
	} else {
		deviceClassPath[0] = CFSTR("Platforms/iPhoneOS.platform/DeviceSupport");
		deviceClassPath[1] = CFSTR("iOS DeviceSupport");
	}
	while (CFArrayGetCount(version_parts) > 0) {
		version = CFStringCreateByCombiningStrings(NULL, version_parts, CFSTR("."));
		NSLogVerbose(@"version: %@", version);
		
		for( int i = 0; i < 2; ++i ) {
			if (path == NULL) {
				path = copy_xcode_path_for(deviceClassPath[i], CFStringCreateWithFormat(NULL, NULL, CFSTR("%@ (%@)/%@"), version, build, suffix));
			}
			
			if (path == NULL) {
				path = copy_xcode_path_for(deviceClassPath[i], CFStringCreateWithFormat(NULL, NULL, CFSTR("%@ (*)/%@"), version, suffix));
			}
			
			if (path == NULL) {
				path = copy_xcode_path_for(deviceClassPath[i], CFStringCreateWithFormat(NULL, NULL, CFSTR("%@/%@"), version, suffix));
			}
			
			if (path == NULL) {
				path = copy_xcode_path_for(deviceClassPath[i], CFStringCreateWithFormat(NULL, NULL, CFSTR("%@.*/%@"), version, suffix));
			}
		}
		
		CFRelease(version);
		if (path != NULL) {
			break;
		}
		CFArrayRemoveValueAtIndex(version_parts, CFArrayGetCount(version_parts) - 1);
	}
	
	for( int i = 0; i < 2; ++i ) {
		if (path == NULL) {
			path = copy_xcode_path_for(deviceClassPath[i], CFStringCreateWithFormat(NULL, NULL, CFSTR("Latest/%@"), suffix));
		}
	}
	
	CFRelease(version_parts);
	CFRelease(build);
	CFRelease(deviceClass);
	if (path == NULL)
		on_error([NSString stringWithFormat:@"Unable to locate DeviceSupport directory with suffix '%@'. This probably means you don't have Xcode installed, you will need to launch the app manually and logging output will not be shown!", suffix]);
	
	time( &endTime );
	NSLogVerbose(@"DeviceSupport directory '%@' was located. It took %.2f seconds", path, difftime(endTime,startTime));
	
	return path;
}
