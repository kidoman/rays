package main

import (
	"fmt"
	"log"
	"os"
)

type image struct {
	size int
	data []byte
}

func newImage(size int) *image {
	return &image{size: size, data: make([]byte, 3*size*size)}
}

func (i *image) Save() {
	f, err := os.Create(*outputfile)
	if err != nil {
		log.Panic(err)
	}
	defer f.Close()

	fmt.Fprintf(f, "P6 %v %v 255 ", i.size, i.size)
	if _, err := f.Write(i.data); err != nil {
		log.Panic(err)
	}
}
