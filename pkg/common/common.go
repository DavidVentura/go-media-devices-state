package common

import "fmt"

type DevType int16

const (
	Undefined DevType = iota
	Cam
	Mic
)

func (d DevType) String() string {
	switch d {
	case Cam:
		return "Camera"
	case Mic:
		return "Microphone"
	case Undefined:
		return "Undefined"
	}
	panic(fmt.Sprintf("Unhandled string case for devtype %v", d))
}

type AVDevice struct {
	Name    string
	Model   string
	Uid     string
	Used    bool
	Devtype DevType
}
