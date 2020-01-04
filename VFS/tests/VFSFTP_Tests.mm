// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import "tests_common.h"
#include <VFS/VFS.h>
#include <VFS/NetFTP.h>
#include <VFS/Native.h>

using namespace nc::vfs;
using namespace std;
using boost::filesystem::path;

static string g_LocalFTP =  NCE(nc::env::test::ftp_qnap_nas_host);
static string g_LocalTestPath = "/Public/!FilesTesting/";

static string UUID()
{
    return [NSUUID.UUID UUIDString].UTF8String;
}

@interface VFSFTP_Tests : XCTestCase
@end

@implementation VFSFTP_Tests

- (void)testLocalFTP
{
    VFSHostPtr host;
    try {
        host = make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    const char *fn1 = "/System/Library/Kernels/kernel",
               *fn2 = "/Public/!FilesTesting/kernel";
    VFSStat stat;
    
    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, stat, 0, 0) == 0)
        XCTAssert( host->Unlink(fn2, 0) == 0);
    
    // copy file to remote server
    XCTAssert( VFSEasyCopyFile(fn1, VFSNativeHost::SharedHost(), fn2, host) == 0);
    int compare;

    // compare it with origin
    XCTAssert( VFSEasyCompareFiles(fn1, VFSNativeHost::SharedHost(), fn2, host, compare) == 0);
    XCTAssert( compare == 0);
    
    // check that it appeared in stat cache
    XCTAssert( host->Stat(fn2, stat, 0, 0) == 0);
    
    // delete it
    XCTAssert( host->Unlink(fn2, 0) == 0);
    XCTAssert( host->Unlink("/Public/!FilesTesting/wf8g2398fg239f6g23976fg79gads", 0) != 0); // also check deleting wrong entry
    
    // check that it is no longer available in stat cache
    XCTAssert( host->Stat(fn2, stat, 0, 0) != 0);
}

- (void)testLocalFTP_EmptyFileTest
{
    VFSHostPtr host;
    try {
        host = make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    const char *fn = "/Public/!FilesTesting/empty_file";

    VFSStat stat;
    if( host->Stat(fn, stat, 0, 0) == 0 )
        XCTAssert( host->Unlink(fn, 0) == 0 );
    
    VFSFilePtr file;
    XCTAssert( host->CreateFile(fn, file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0 );
    XCTAssert( file->IsOpened() == true );
    XCTAssert( file->Close() == 0);

    // sometimes this fail. mb caused by FTP server implementation (?)
    XCTAssert( host->Stat(fn, stat, 0, 0) == 0);
    XCTAssert( stat.size == 0);
    
    XCTAssert( file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoExist) != 0 );
    XCTAssert( file->IsOpened() == false );
    
    XCTAssert( host->Unlink(fn, 0) == 0 );
    XCTAssert( host->Stat(fn, stat, 0, 0) != 0);
}

- (void) testLocal_MKD_RMD
{
    VFSHostPtr host;
    try {
        host = make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    for(auto dir: {g_LocalTestPath + UUID(),
                   g_LocalTestPath + string(@"В лесу родилась елочка, В лесу она росла".UTF8String),
                   g_LocalTestPath + string(@"北京市 >≥±§ 😱".UTF8String)
        })
    {
        XCTAssert( host->CreateDirectory(dir.c_str(), 0755, 0) == 0 );
        XCTAssert( host->IsDirectory(dir.c_str(), 0, 0) == true );
        XCTAssert( host->RemoveDirectory(dir.c_str(), 0) == 0 );
        XCTAssert( host->IsDirectory(dir.c_str(), 0, 0) == false );
    }
    
    for(auto dir: {g_LocalTestPath + "some / very / bad / filename",
                   "/some/another/invalid/path"s
        })
    {
        XCTAssert( host->CreateDirectory(dir.c_str(), 0755, 0) != 0 );
        XCTAssert( host->IsDirectory(dir.c_str(), 0, 0) == false );
    }
}

- (void) testLocal_Rename_NAS
{
    VFSHostPtr host;
    try {
        host = make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    string fn1 = "/System/Library/Kernels/kernel", fn2 = g_LocalTestPath + "kernel", fn3 = g_LocalTestPath + "kernel34234234";
    
    VFSStat stat;
    
    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2.c_str(), stat, 0, 0) == 0)
        XCTAssert( host->Unlink(fn2.c_str(), 0) == 0);
    
    XCTAssert( VFSEasyCopyFile(fn1.c_str(), VFSNativeHost::SharedHost(), fn2.c_str(), host) == 0);
    XCTAssert( host->Rename(fn2.c_str(), fn3.c_str(), 0) == 0);
    XCTAssert( host->Stat(fn3.c_str(), stat, 0, 0) == 0);
    XCTAssert( host->Unlink(fn3.c_str(), 0) == 0);


    if( host->Stat((g_LocalTestPath + "DirectoryName1").c_str(), stat, 0, 0) == 0)
        XCTAssert( host->RemoveDirectory((g_LocalTestPath + "DirectoryName1").c_str(), 0) == 0);
    if( host->Stat((g_LocalTestPath + "DirectoryName2").c_str(), stat, 0, 0) == 0)
        XCTAssert( host->RemoveDirectory((g_LocalTestPath + "DirectoryName2").c_str(), 0) == 0);
    
    XCTAssert( host->CreateDirectory((g_LocalTestPath + "DirectoryName1").c_str(), 0755, 0) == 0);
    XCTAssert( host->Rename((g_LocalTestPath + "DirectoryName1/").c_str(),
                            (g_LocalTestPath + "DirectoryName2/").c_str(),
                            0) == 0);
    XCTAssert( host->Stat((g_LocalTestPath + "DirectoryName2").c_str(), stat, 0, 0) == 0);
    XCTAssert( host->RemoveDirectory((g_LocalTestPath + "DirectoryName2").c_str(), 0) == 0);
}

- (void)testListing_utexas_edu
{
    auto path = "/pub/debian-cd";
    VFSHostPtr host;
    try {
        host = make_shared<FTPHost>("ftp.utexas.edu", "", "", path);
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    set<string> should_be = {"10.2.0", "10.2.0-live", "current", "current-live", "ls-lR.gz", "project"};
    set<string> in_fact;
    
    XCTAssert( host->IterateDirectoryListing(path, [&](const VFSDirEnt &_dirent) {
            in_fact.emplace(_dirent.name);
            return true;
        }) == 0);
    XCTAssert(should_be == in_fact);
}

- (void)testSeekRead_utexas_edu
{
    try {
        const auto host_name = "ftp.utexas.edu";
        const auto host_dir = "/pub/debian-cd/10.2.0/i386/iso-cd/";
        const auto host_path = "/pub/debian-cd/10.2.0/i386/iso-cd/debian-10.2.0-i386-netinst.iso";
        const auto offset = 0x1D79AC0;
        const auto length = 16; 
        const auto expected = "\x1b\x5a\x65\x00\x55\x57\xae\xcc\x1a\xeb\xa9\xe3\x92\xb0\x98\x9c";
        
        const auto host = make_shared<FTPHost>(host_name, "", "", host_dir);
        
        // check seeking at big distance and reading an arbitrary selected known data block
        VFSFilePtr file;
        char buf[4096];
        XCTAssert( host->CreateFile(host_path, file, 0) == 0 );        
        XCTAssert( file->Open(VFSFlags::OF_Read) == 0 );
        XCTAssert( file->Seek(offset, VFSFile::Seek_Set) == offset);
        XCTAssert( file->Read(buf, length) == length );        
        XCTAssert( memcmp(buf, expected, length) == 0 );
        
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testListing_RedHat_Com
{
    auto path = "/redhat/dst2007/APPLICATIONS/";
    VFSHostPtr host;
    try {
        host = make_shared<FTPHost>("ftp.redhat.com", "", "", path);
    } catch (VFSErrorException &e) {
        XCTAssert( 0 );
        return;
    }
    set<string> should_be = {"evolution", "evolution-data-server", "gcj", "IBMJava2-JRE", "IBMJava2-SDK", "java-1.4.2-bea", "java-1.4.2-ibm", "rhn_satellite_java_update"};
    set<string> in_fact;
    
    XCTAssert( host->IterateDirectoryListing(path, [&](const VFSDirEnt &_dirent) {
        in_fact.emplace(_dirent.name);
        return true;
    }) == 0);
    XCTAssert(should_be == in_fact);
}

- (void)testBigFilesReadingCancellation
{
    const auto host_name = "ftp.utexas.edu";
    const auto host_dir = "/pub/debian-cd/10.2.0/i386/iso-cd/";
    const auto host_path = "/pub/debian-cd/10.2.0/i386/iso-cd/debian-10.2.0-i386-netinst.iso";
    
    VFSHostPtr host;
    try {
        host = make_shared<FTPHost>(host_name, "", "", host_dir);
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;        
    }    
  
    __block bool finished = false;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        VFSFilePtr file;
        char buf[256];
        XCTAssert( host->CreateFile(host_path, file, 0) == 0 );
        XCTAssert( file->Open(VFSFlags::OF_Read) == 0 );
        XCTAssert( file->Read(buf, sizeof(buf)) == sizeof(buf) );
        XCTAssert( file->Close() == 0 ); // at this moment we have read only a small part of file
                                         // and Close() should tell curl to stop reading and will wait for a pending operations to be finished
        finished = true;
    });
    
    [self waitUntilFinish:finished];
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    using namespace std::chrono;
    microseconds sleeped = 0us, sleep_tresh = 60s;
    while (!_finished)
    {
        this_thread::sleep_for(100us);
        sleeped += 100us;
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}

@end

