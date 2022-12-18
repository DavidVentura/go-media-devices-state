#import <AVFoundation/AVFoundation.h>
#import <CoreMediaIO/CMIOHardware.h>
#import <Foundation/Foundation.h>

// TODO how to use single `common/errno.mm` file for both packages?
const int VD_ERR_NO_ERR = 0;
const int VD_ERR_OUT_OF_MEMORY = 1;
const int VD_ERR_ALL_DEVICES_FAILED = 2;
const int VD_ERR_NO_DEV_WITH_ID = 3;

bool isIgnoredDeviceUID(NSString *uid) {
  // OBS virtual device always returns "is used" even when OBS is not running
  if ([uid isEqual:@"obs-virtual-cam-device"]) {
    return true;
  }
  return false;
}

OSStatus getVideoDevicesCount(int *count) {
  OSStatus err;
  UInt32 dataSize = 0;

  CMIOObjectPropertyAddress prop = {kCMIOHardwarePropertyDevices,
                                    kCMIOObjectPropertyScopeGlobal,
                                    kCMIOObjectPropertyElementMaster};

  err = CMIOObjectGetPropertyDataSize(kCMIOObjectSystemObject, &prop, 0, nil,
                                      &dataSize);
  if (err != kCMIOHardwareNoError) {
    NSLog(@"getVideoDevicesCount(): error: %d", err);
    return err;
  }

  *count = dataSize / sizeof(CMIODeviceID);

  return err;
}

OSStatus getVideoDevices(int count, CMIODeviceID *devices) {
  OSStatus err;
  UInt32 dataSize = 0;
  UInt32 dataUsed = 0;

  CMIOObjectPropertyAddress prop = {kCMIOHardwarePropertyDevices,
                                    kCMIOObjectPropertyScopeGlobal,
                                    kCMIOObjectPropertyElementMaster};

  err = CMIOObjectGetPropertyDataSize(kCMIOObjectSystemObject, &prop, 0, nil,
                                      &dataSize);
  if (err != kCMIOHardwareNoError) {
    NSLog(@"getVideoDevices(): get data size error: %d", err);
    return err;
  }

  err = CMIOObjectGetPropertyData(kCMIOObjectSystemObject, &prop, 0, nil,
                                  dataSize, &dataUsed, devices);
  if (err != kCMIOHardwareNoError) {
    NSLog(@"getVideoDevices(): get data error: %d", err);
    return err;
  }

  return err;
}

OSStatus getVideoDeviceUID(CMIOObjectID device, NSString **uid) {
  OSStatus err;
  UInt32 dataSize = 0;
  UInt32 dataUsed = 0;

  CMIOObjectPropertyAddress prop = {kCMIODevicePropertyDeviceUID,
                                    kCMIOObjectPropertyScopeWildcard,
                                    kCMIOObjectPropertyElementWildcard};

  err = CMIOObjectGetPropertyDataSize(device, &prop, 0, nil, &dataSize);
  if (err != kCMIOHardwareNoError) {
    NSLog(@"getVideoDeviceUID(): get data size error: %d", err);
    return err;
  }

  CFStringRef uidStringRef = NULL;
  err = CMIOObjectGetPropertyData(device, &prop, 0, nil, dataSize, &dataUsed,
                                  &uidStringRef);
  if (err != kCMIOHardwareNoError) {
    NSLog(@"getVideoDeviceUID(): get data error: %d", err);
    return err;
  }

  *uid = (NSString *)uidStringRef;

  return err;
}

OSStatus getVideoDeviceNameAndModel(NSString *uid, NSString **name, NSString **model) {
  OSStatus err = VD_ERR_NO_ERR;
  AVCaptureDevice *avDevice = [AVCaptureDevice deviceWithUniqueID:uid];
  if (avDevice == nil) {
    err = VD_ERR_NO_DEV_WITH_ID;
  } else {
    *name = [avDevice localizedName];
    *model = [avDevice modelID];
  }
  return err;
}

OSStatus getVideoDeviceIsUsed(CMIOObjectID device, int *isUsed) {
  OSStatus err;
  UInt32 dataSize = 0;
  UInt32 dataUsed = 0;

  CMIOObjectPropertyAddress prop = {kCMIODevicePropertyDeviceIsRunningSomewhere,
                                    kCMIOObjectPropertyScopeWildcard,
                                    kCMIOObjectPropertyElementWildcard};

  err = CMIOObjectGetPropertyDataSize(device, &prop, 0, nil, &dataSize);
  if (err != kCMIOHardwareNoError) {
    NSLog(@"getVideoDeviceIsUsed(): get data size error: %d", err);
    return err;
  }

  err = CMIOObjectGetPropertyData(device, &prop, 0, nil, dataSize, &dataUsed,
                                  isUsed);
  if (err != kCMIOHardwareNoError) {
    NSLog(@"getVideoDeviceIsUsed(): get data error: %d", err);
    return err;
  }

  return err;
}

@interface VideoDevice : NSObject
    @property (assign) bool used;
    @property (assign) NSString *uid;
    @property (assign) NSString *name;
    @property (assign) NSString *model;
@end
@implementation VideoDevice
    @synthesize used;
    @synthesize uid;
    @synthesize name;
    @synthesize model;
@end

NSMutableArray *devArray;
const bool used_at(unsigned int i) {
    if (i >= devArray.count) return NULL;
    VideoDevice *vd = [devArray objectAtIndex:i];
    return vd.used;
}
const char* uid_at(unsigned int i) {
    if (i >= devArray.count) return NULL;
    VideoDevice *vd = [devArray objectAtIndex:i];
    const char *cstr = [vd.uid UTF8String];
    return cstr;
}
const char* name_at(unsigned int i) {
    if (i >= devArray.count) return NULL;
    VideoDevice *vd = [devArray objectAtIndex:i];
    const char *cstr = [vd.name UTF8String];
    return cstr;
}
const char* model_at(unsigned int i) {
    if (i >= devArray.count) return NULL;
    VideoDevice *vd = [devArray objectAtIndex:i];
    const char *cstr = [vd.model UTF8String];
    return cstr;
}

unsigned long vid_dev_len() {
    return devArray.count;
}

void vid_dev_init() {
    devArray = [[NSMutableArray alloc] init];
}

VideoDevice* vid_dev(unsigned int i) {
    if (i >= devArray.count) return NULL;
    return [devArray objectAtIndex:i];
}

void UpdateCameraStatus(OSStatus *error) {
  OSStatus err;

  int count;
  err = getVideoDevicesCount(&count);
  if (err) {
    NSLog(@"C.IsCameraOn(): failed to get devices count, error: %d", err);
    *error = err;
    return;
  }

  CMIODeviceID *devices = (CMIODeviceID *)malloc(count * sizeof(*devices));
  if (devices == NULL) {
    NSLog(@"C.IsCameraOn(): failed to allocate memory, device count: %d",
          count);
    *error = VD_ERR_OUT_OF_MEMORY;
    return;
  }

  err = getVideoDevices(count, devices);
  if (err) {
    NSLog(@"C.IsCameraOn(): failed to get devices, error: %d", err);
    free(devices);
    devices = NULL;
    *error = err;
    return;
  }

  int failedDeviceCount = 0;
  int ignoredDeviceCount = 0;

  [devArray removeAllObjects];
  for (int i = 0; i < count; i++) {
    CMIOObjectID device = devices[i];

    NSString *uid;
    err = getVideoDeviceUID(device, &uid);
    if (err) {
      failedDeviceCount++;
      NSLog(@"C.IsCameraOn(): %d | -       | failed to get device UID: %d", i,
            err);
      continue;
    }

    if (isIgnoredDeviceUID(uid)) {
      ignoredDeviceCount++;
      continue;
    }

    int isDeviceUsed;
    err = getVideoDeviceIsUsed(device, &isDeviceUsed);
    if (err) {
      failedDeviceCount++;
      NSLog(@"C.IsCameraOn(): %d | -       | failed to get device status: %d",
            i, err);
      continue;
    }

    NSString *name;
    NSString *model;
    err = getVideoDeviceNameAndModel(uid, &name, &model);
    if (err) {
      failedDeviceCount++;
      NSLog(@"C.IsCameraOn(): %d | -       | failed to get device name/model: %d",
            i, err);
      continue;
    }
 
    VideoDevice *vd = [VideoDevice alloc];
    vd.uid = uid;
    vd.used = isDeviceUsed;
    vd.name = name;
    vd.model = model;

    [devArray addObject: vd];
  }

  free(devices);
  devices = NULL;

  if (failedDeviceCount == count) {
    *error = VD_ERR_ALL_DEVICES_FAILED;
    return;
  }

  *error = VD_ERR_NO_ERR;
  //NSArray *ret = [devArray copy];
  //[devArray release];
  return;
}
