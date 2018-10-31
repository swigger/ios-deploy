#pragma once
#include "MobileDevice.h"
#ifdef __cplusplus
extern "C"{
#endif

typedef struct am_device * AMDeviceRef;
mach_error_t AMDeviceSecureStartService(struct am_device *device, CFStringRef service_name, unsigned int *unknown, service_conn_t *handle);
int AMDeviceSecureTransferPath(int zero, AMDeviceRef device, CFURLRef url, CFDictionaryRef options, void *callback, int cbarg);
int AMDeviceSecureInstallApplication(int zero, AMDeviceRef device, CFURLRef url, CFDictionaryRef options, void *callback, int cbarg);
int AMDeviceMountImage(AMDeviceRef device, CFStringRef image, CFDictionaryRef options, void *callback, int cbarg);
mach_error_t AMDeviceLookupApplications(AMDeviceRef device, CFDictionaryRef options, CFDictionaryRef *result);
int AMDeviceGetInterfaceType(struct am_device *device);


typedef struct errorcode_to_id {
	unsigned int error;
	const char*  id;
} errorcode_to_id_t;

typedef struct error_id_to_message {
	const char* id;
	const char* message;
} error_id_to_message_t;

typedef struct {
	CFStringRef model;
	CFStringRef name;
	CFStringRef sdk;
	CFStringRef arch;
} device_desc;

// Error codes we report on different failures, so scripts can distinguish between user app exit
// codes and our exit codes. For non app errors we use codes in reserved 128-255 range.
enum SpecialExitCode
{
	exitcode_timeout = 252,
	exitcode_error = 253,
	exitcode_app_crash = 254
};

// Checks for MobileDevice.framework errors, tries to print them and exits.
#define check_error(call)                                                       \
	do {                                                                        \
		unsigned int err = (unsigned int)call;                                  \
		if (err != 0)                                                           \
		{                                                                       \
			const char* msg = get_error_message(err);                           \
			/*on_error("Error 0x%x: %s " #call, err, msg ? msg : "unknown.");*/ \
			on_error(@"Error 0x%x: %@ " #call, err, msg ? [NSString stringWithUTF8String:msg] : @"unknown."); \
		}                                                                       \
	} while (false);

#define MY_VERSION "1.9.4"

extern int g_log_level;
void NSLogOut(NSString* format, ...);
void NSLogVerbose(NSString* format, ...);

void on_error(NSString* format, ...);
void on_sys_error(NSString* format, ...);
const char* get_error_message(unsigned int error);
device_desc get_device_desc(CFStringRef model);
void debug_error_table(void);

BOOL mkdirp(NSString* path);

CFStringRef copy_device_support_path(AMDeviceRef device, CFStringRef suffix);
CFStringRef copy_disk_app_identifier(CFURLRef disk_app_url);
CFURLRef copy_device_app_url(AMDeviceRef device, CFStringRef identifier);

#ifdef __cplusplus
}
#endif
