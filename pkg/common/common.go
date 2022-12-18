package common

type DevType int16

const (
	Cam DevType = 0
	Mic DevType = 1
)

type AVDevice struct {
	Name    string
	Model   string
	Uid     string
	Used    bool
	Devtype DevType
}
