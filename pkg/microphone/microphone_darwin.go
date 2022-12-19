package microphone

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation
#cgo LDFLAGS: -framework AVFoundation
#cgo LDFLAGS: -framework CoreAudio
#include "microphone_darwin.mm"
*/
import "C"
import (
	"fmt"

	"github.com/davidventura/go-media-devices-state/pkg/common"
)

func InitAudioDevices() {
	C.mic_dev_init()
}

func mic_dev(i uint) common.AVDevice {
	vd := common.AVDevice{
		Name:    C.GoString(C.a_name_at(C.uint(i))),
		Model:   C.GoString(C.a_model_at(C.uint(i))),
		Uid:     C.GoString(C.a_uid_at(C.uint(i))),
		Used:    bool(C.a_used_at(C.uint(i))),
		Devtype: common.Mic,
	}
	return vd
}

func audioDevices() ([]common.AVDevice, error) {
	err := C.int(0)
	C.UpdateMicrophoneStatus(&err)

	if err != common.ErrNoErr {
		var msg string
		switch err {
		case common.ErrOutOfMemory:
			msg = "IsMicrophoneOn(): failed to allocate memory"
		case common.ErrAllDevicesFailed:
			msg = "IsMicrophoneOn(): all devices failed to provide status"
		default:
			msg = fmt.Sprintf("IsMicrophoneOn(): failed with error code: %d", err)
		}
		return nil, fmt.Errorf("IsMicrophoneOn(): %s", msg)
	}

	dev_count := uint(C.mic_dev_len())
	ret := make([]common.AVDevice, dev_count)
	for i := uint(0); i < dev_count; i++ {
		ret[i] = mic_dev(i)
	}
	return ret, nil
}

// IsMicrophoneOn returns true is any microphone in the system is ON
func IsMicrophoneOn() (bool, error) {
	isMicrophoneOn := false
	devs, err := audioDevices()
	if err != nil {
		return false, err
	}
	for _, dev := range devs {
		// fmt.Printf("%#v\n", dev)
		if dev.Used {
			isMicrophoneOn = true
		}
	}
	return isMicrophoneOn, nil
}
