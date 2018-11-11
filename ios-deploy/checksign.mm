#import <Foundation/Foundation.h>
#import "common.h"
#include "checksign.h"
#include <sys/stat.h>
#include <string>

using std::string;

int x_exec(int & readhd, const string & con, const char * file, const char ** argv)
{
	struct {
		int s_read;
		int m_wrte;
		int m_read;
		int s_wrte;
	}ps;
	memset(&ps, -1, sizeof(ps));
	if (pipe(&ps.s_read)==0 && pipe(&ps.m_read)==0)
	{
		int ix = fork();
		if (ix < 0) return ix;
		if (ix == 0)
		{
			dup2(ps.s_read, 0);
			dup2(ps.s_wrte, 1);
			close(ps.s_read);
			close(ps.s_wrte);
			close(ps.m_wrte);
			close(ps.m_read);
			execvp(file, (char**)argv);
			exit(1);
		}
		else
		{
			close(ps.s_wrte);
			close(ps.s_read);
			write(ps.m_wrte, con.data(), con.length());
			close(ps.m_wrte);
			readhd = ps.m_read;
			return ix;
		}
	}
	else
	{
		if (ps.s_read >= 0) close(ps.s_read);
		if (ps.m_read >= 0) close(ps.m_read);
		if (ps.m_wrte >= 0) close(ps.m_wrte);
		if (ps.s_wrte >= 0) close(ps.s_wrte);
		return -1;
	}
}

bool read_all(const char * fp, string & res)
{
	int fd = open(fp, O_RDONLY);
	if (fd < 0) return false;
	struct stat st;
	if (fstat(fd, &st))
	{
	err:
		close(fd);
		return false;
	}
	if (st.st_size > 0)
	{
		res.resize(st.st_size);
		ssize_t n = read(fd, &res[0], st.st_size);
		if (n < 0) goto err;
		res.resize(n);
	}
	close(fd);
	return true;
}

bool check_sign(const char* devname, const string & plist)
{
	if (!devname || plist.length() == 0)
		return false;
	NSError * err = 0;
	NSData * data = [NSData dataWithBytes:plist.data() length:plist.length()];
	NSDictionary  * dict = [NSPropertyListSerialization propertyListWithData:data options:0 format:0 error:&err];
	if (!dict) return false;
	NSDate * exp = (NSDate*)[dict objectForKey:@"ExpirationDate"];
	if ([[NSDate date] compare:exp] == NSOrderedDescending )
	{
		fprintf(stderr, "ERROR: the signed provision file has expired.\n");
		return false;
	}
	bool ball = [[dict objectForKey:@"ProvisionsAllDevices"] boolValue];
	if (!ball)
	{
		NSArray * devs = [dict objectForKey:@"ProvisionedDevices"];
		bool devok = false;
		for (NSString * d in devs)
		{
			if (strcasecmp(devname, [d UTF8String]) == 0)
			{
				devok = true;
				break;
			}
		}
		if (!devok)
		{
			fprintf(stderr, "ERROR: device %s is not in ProvisionedDevices.\n", devname);
			return false;
		}
	}
	
	return true;
}

bool check_sign(CFStringRef devname, CFStringRef path)
{
	char buf[4096];
	string sp = CFStringGetCStringPtr(path, kCFStringEncodingUTF8);
	sp += "/embedded.mobileprovision";
	string con;
	if (!read_all(sp.c_str(), con))
		return false;
	
	int readhd = -1;
	const char * argv[] = {"security", "cms", "-D", 0};
	int sub = x_exec(readhd, con, argv[0], argv);
	if (sub < 0) return false;

	string rr;
	for (;;)
	{
		ssize_t n = read(readhd, buf, sizeof(buf));
		if (n <= 0) break;
		rr.append(buf, n);
	}
	int c = 0;
	waitpid(sub, &c, 0);
	if (c!=0) return false;
	
	return check_sign(CFStringGetCStringPtr(devname, kCFStringEncodingUTF8), rr);
}

