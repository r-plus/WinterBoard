#include <unistd.h>
#include <fcntl.h>

#import <Foundation/Foundation.h>
#import <BluetoothManager/BluetoothManager.h>
#import <SpringBoard/SBBluetoothController.h>

static unsigned connectedDevices_;

@interface SBBluetoothController (_WinterBoard)
- (void) wb_noteDevicesChanged;
@end

@implementation SBBluetoothController (WinterBoard)

- (void) noteDevicesChanged {
    if (NSArray *devices = [[BluetoothManager sharedInstance] pairedDevices]) {
        connectedDevices_ = 0;
        for (int i = 0, e = [devices count]; i != e; ++i)
            if ([[devices objectAtIndex:i] connected])
                ++connectedDevices_;
        if (connectedDevices_ == 0)
            unlink("/tmp/neuter");
        else
            close(open("/tmp/neuter", O_CREAT | O_TRUNC | O_WRONLY, 644));
    }

    [self wb_noteDevicesChanged];
}

@end
