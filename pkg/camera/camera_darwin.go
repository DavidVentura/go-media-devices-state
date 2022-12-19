package camera

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation
#cgo LDFLAGS: -framework AVFoundation
#cgo LDFLAGS: -framework CoreMediaIO
#include "camera_darwin.mm"
*/
import "C"
import (
	"fmt"

	"github.com/davidventura/go-media-devices-state/pkg/common"
)

func vid_dev(i uint) common.AVDevice {
	vd := common.AVDevice{
		Name:    C.GoString(C.name_at(C.uint(i))),
		Model:   C.GoString(C.model_at(C.uint(i))),
		Uid:     C.GoString(C.uid_at(C.uint(i))),
		Used:    bool(C.used_at(C.uint(i))),
		Devtype: common.Cam,
	}
	return vd
}

func InitCamDevices() {
	C.vid_dev_init()
}

func videoDevices() ([]common.AVDevice, error) {
	err := C.int(0)
	C.UpdateCameraStatus(&err)

	if err != common.ErrNoErr {
		var msg string
		switch err {
		case common.ErrOutOfMemory:
			msg = "IsCameraOn(): failed to allocate memory"
		case common.ErrAllDevicesFailed:
			msg = "IsCameraOn(): all devices failed to provide status"
		default:
			msg = fmt.Sprintf("IsCameraOn(): failed with error code: %d", err)
		}
		return nil, fmt.Errorf("IsCameraOn(): %s", msg)
	}

	dev_count := uint(C.vid_dev_len())
	ret := make([]common.AVDevice, dev_count)
	for i := uint(0); i < dev_count; i++ {
		ret[i] = vid_dev(i)
	}
	return ret, nil
}

// IsCameraOn returns true is any camera in the system is ON
func IsCameraOn() (bool, error) {
	isCameraOn := false
	devs, err := videoDevices()
	if err != nil {
		return false, err
	}
	for _, dev := range devs {
		// fmt.Printf("%#v\n", dev)
		if dev.Used {
			isCameraOn = true
		}
	}
	return isCameraOn, nil
}
