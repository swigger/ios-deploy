#pragma once
#include "common.h"

#ifdef __cplusplus
extern "C"{
#endif
	
struct script_options
{
	int detectDeadlockTimeout; //=0
	char * args;
	int port; //device port
	const char * extra_cmds;
	
	NSString * lldb_cmd_path;
};
extern struct script_options g_scopt;

void write_lldb_prep_cmds(AMDeviceRef device, CFURLRef disk_app_url);

#ifdef __cplusplus
}
#endif
