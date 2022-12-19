package microphone

import (
	"errors"
	"fmt"
	"time"

	"github.com/davidventura/go-media-devices-state/pkg/common"
	"github.com/noisetorch/pulseaudio"
)

type SourceState int16

var client *pulseaudio.Client = nil

// https://gitlab.freedesktop.org/pulseaudio/pulseaudio/-/blob/master/src/utils/pactl.c#L546
const (
	Running SourceState = iota
	Idle
	Suspended
)
const NOT_A_MONITOR_SOURCE uint32 = 4294967295

func (s SourceState) String() string {
	switch s {
	case Running:
		return "Running"
	case Idle:
		return "Idle"
	case Suspended:
		return "Suspended"
	}
	return "Unknown state"
}

func makeClient() (*pulseaudio.Client, error) {
	var err error
	const retries int = 5
	for i := range [retries]int{} {
		client, err := pulseaudio.NewClient()
		if err == nil {
			return client, nil
		}
		fmt.Printf("Failed to make a client: %s\n", err)
		retriesLeft := retries - i
		if retriesLeft > 0 {
			fmt.Printf("Retrying %d more times\n", retriesLeft)
			time.Sleep(1 * time.Second)
		}
	}
	return nil, err
}

func InitAudioDevices() {
	_client, err := makeClient()
	if err != nil {
		panic(err)
	}
	client = _client
}

func IsMicrophoneOn() (bool, error) {
	devs, err := audioDevices()
	if err != nil {
		return false, err
	}
	for _, dev := range devs {
		if dev.Used {
			return true, nil
		}
	}
	return false, nil
}

func getName(props map[string]string) string {
	keysByPref := []string{"device.description", "node.nick", "api.alsa.card.name", "node.name", "api.alsa.card.longname"}
	for _, k := range keysByPref {
		v, found := props[k]
		if found {
			return v
		}
	}
	return "No Name"

	/*
		device.description      Blue Snowball Pro
		node.nick       Blue Snowball
		api.alsa.card.name      Blue Snowball
		node.name       alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_797_2019_07_20_33670-00.pro-input-0
		api.alsa.card.longname  BLUE MICROPHONE Blue Snowball at usb-0000:00:05.0-3, full speed
	*/

}
func audioDevices() ([]common.AVDevice, error) {
	if client == nil || !client.Connected() {
		if client != nil {
			client.Close()
		}
		_client, err := makeClient()
		if err != nil {
			panic(err)
		}
		client = _client
	}
	sources, err := client.Sources()
	if err != nil {
		return nil, errors.New(fmt.Sprintf("Failed to get sources: %s\n", err))
	}
	ret := make([]common.AVDevice, 0)
	for _, source := range sources {
		if source.MonitorSourceIndex != NOT_A_MONITOR_SOURCE {
			continue
		}
		state := SourceState(source.SinkState)
		vd := common.AVDevice{
			Name:    source.Description,
			Model:   getName(source.PropList),
			Uid:     "No such thing",
			Used:    state == Running,
			Devtype: common.Mic,
		}

		ret = append(ret, vd)
	}
	return ret, nil
}
