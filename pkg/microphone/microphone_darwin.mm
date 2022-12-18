#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/AudioHardware.h>
#import <Foundation/Foundation.h>

// TODO how to use single `common/errno.mm` file for both packages?
const int AD_ERR_NO_ERR = 0;
const int AD_ERR_OUT_OF_MEMORY = 1;
const int AD_ERR_ALL_DEVICES_FAILED = 2;
const int AD_ERR_NO_DEV_WITH_ID = 3;

OSStatus getAudioDevicesCount(int *count) {
  OSStatus err;
  UInt32 dataSize = 0;

  AudioObjectPropertyAddress prop = {kAudioHardwarePropertyDevices,
                                     kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMaster};

  err = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &prop, 0, nil,
                                       &dataSize);
  if (err != kAudioHardwareNoError) {
    NSLog(@"getAudioDevicesCount(): error: %d", err);
    return err;
  }

  *count = dataSize / sizeof(AudioDeviceID);

  return err;
}

OSStatus getAudioDevices(int count, AudioDeviceID *devices) {
  OSStatus err;
  UInt32 dataSize = 0;

  AudioObjectPropertyAddress prop = {kAudioHardwarePropertyDevices,
                                     kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMaster};

  err = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &prop, 0, nil,
                                       &dataSize);
  if (err != kAudioHardwareNoError) {
    NSLog(@"getAudioDevices(): get data size error: %d", err);
    return err;
  }

  err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &prop, 0, nil,
                                   &dataSize, devices);
  if (err != kAudioHardwareNoError) {
    NSLog(@"getAudioDevices(): get data error: %d", err);
    return err;
  }

  return err;
}

OSStatus getAudioDeviceUID(AudioDeviceID device, NSString **uid) {
  OSStatus err;
  UInt32 dataSize = 0;

  AudioObjectPropertyAddress prop = {kAudioDevicePropertyDeviceUID,
                                     kAudioObjectPropertyScopeGlobal,
                                     kAudioObjectPropertyElementMaster};

  err = AudioObjectGetPropertyDataSize(device, &prop, 0, nil, &dataSize);
  if (err != kAudioHardwareNoError) {
    NSLog(@"getAudioDeviceUID(): get data size error: %d", err);
    return err;
  }

  CFStringRef uidStringRef = NULL;
  err = AudioObjectGetPropertyData(device, &prop, 0, nil, &dataSize,
                                   &uidStringRef);
  if (err != kAudioHardwareNoError) {
    NSLog(@"getAudioDeviceUID(): get data error: %d", err);
    return err;
  }

  *uid = (NSString *)uidStringRef;

  return err;
}

bool isAudioCaptureDevice(NSString *uid) {
  AVCaptureDevice *avDevice = [AVCaptureDevice deviceWithUniqueID:uid];
  return avDevice != nil;
}

//FIXME common?
OSStatus getAudioDeviceNameAndModel(NSString *uid, NSString **name, NSString **model) {
  OSStatus err = AD_ERR_NO_ERR;
  AVCaptureDevice *avDevice = [AVCaptureDevice deviceWithUniqueID:uid];
  if (avDevice == nil) {
    err = AD_ERR_NO_DEV_WITH_ID;
  } else {
    *name = [avDevice localizedName];
    *model = [avDevice modelID];
  }
  return err;
}

OSStatus getAudioDeviceIsUsed(AudioDeviceID device, int *isUsed) {
  OSStatus err;
  UInt32 dataSize = 0;

  AudioObjectPropertyAddress prop = {
      kAudioDevicePropertyDeviceIsRunningSomewhere,
      kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster};

  err = AudioObjectGetPropertyDataSize(device, &prop, 0, nil, &dataSize);
  if (err != kAudioHardwareNoError) {
    NSLog(@"getAudioDeviceIsUsed(): get data size error: %d", err);
    return err;
  }

  err = AudioObjectGetPropertyData(device, &prop, 0, nil, &dataSize, isUsed);
  if (err != kAudioHardwareNoError) {
    NSLog(@"getAudioDeviceIsUsed(): get data error: %d", err);
    return err;
  }

  return err;
}
@interface AudioDevice : NSObject
    @property (assign) bool used;
    @property (assign) NSString *uid;
    @property (assign) NSString *name;
    @property (assign) NSString *model;
@end

@implementation AudioDevice
    @synthesize used;
    @synthesize uid;
    @synthesize name;
    @synthesize model;
@end

NSMutableArray *aDevArray;
unsigned long mic_dev_len() {
    return aDevArray.count;
}

void mic_dev_init() {
    aDevArray = [[NSMutableArray alloc] init];
}
const bool a_used_at(unsigned int i) {
    if (i >= aDevArray.count) return NULL;
    AudioDevice *vd = [aDevArray objectAtIndex:i];
    return vd.used;
}
const char* a_uid_at(unsigned int i) {
    if (i >= aDevArray.count) return NULL;
    AudioDevice *vd = [aDevArray objectAtIndex:i];
    const char *cstr = [vd.uid UTF8String];
    return cstr;
}
const char* a_name_at(unsigned int i) {
    if (i >= aDevArray.count) return NULL;
    AudioDevice *vd = [aDevArray objectAtIndex:i];
    const char *cstr = [vd.name UTF8String];
    return cstr;
}
const char* a_model_at(unsigned int i) {
    if (i >= aDevArray.count) return NULL;
    AudioDevice *vd = [aDevArray objectAtIndex:i];
    const char *cstr = [vd.model UTF8String];
    return cstr;
}

void UpdateMicrophoneStatus(OSStatus *error) {
  OSStatus err;

  int count;
  err = getAudioDevicesCount(&count);
  if (err) {
    NSLog(@"C.IsMicrophoneOn(): failed to get devices count, error: %d", err);
    *error = err;
    return;
  }

  AudioDeviceID *devices = (AudioDeviceID *)malloc(count * sizeof(*devices));
  if (devices == NULL) {
    NSLog(@"C.IsMicrophoneOn(): failed to allocate memory, device count: %d",
          count);
    *error = AD_ERR_OUT_OF_MEMORY;
  }

  err = getAudioDevices(count, devices);
  if (err) {
    NSLog(@"C.IsMicrophoneOn(): failed to get devices, error: %d", err);
    free(devices);
    devices = NULL;
    *error = err;
    return;
  }

  int failedDeviceCount = 0;
  int ignoredDeviceCount = 0;

  [aDevArray removeAllObjects];
  for (int i = 0; i < count; i++) {
    AudioDeviceID device = devices[i];

    NSString *uid;
    err = getAudioDeviceUID(device, &uid);
    if (err) {
      failedDeviceCount++;
      NSLog(@"C.IsMicrophoneOn(): %d | -       | failed to get device UID: %d",
            i, err);
      continue;
    }

    if (!isAudioCaptureDevice(uid)) {
      ignoredDeviceCount++;
      continue;
    }

    int isDeviceUsed;
    err = getAudioDeviceIsUsed(device, &isDeviceUsed);
    if (err) {
      failedDeviceCount++;
      NSLog(
          @"C.IsMicrophoneOn(): %d | -       | failed to get device state: %d",
          i, err);
      continue;
    }

    NSString *name;
    NSString *model;
    err = getAudioDeviceNameAndModel(uid, &name, &model);
    if (err) {
      failedDeviceCount++;
      NSLog(@"C.IsMicrophoneOn(): %d | -       | failed to get device name/model: %d",
            i, err);
      continue;
    }

    AudioDevice *ad = [AudioDevice alloc];
    ad.uid = uid;
    ad.used = isDeviceUsed;
    ad.name = name;
    ad.model = model;

    [aDevArray addObject: ad];

  }

  free(devices);
  devices = NULL;

  if (failedDeviceCount == count) {
    *error = err;
    return;
  }

  *error = AD_ERR_NO_ERR;
  return;
}
