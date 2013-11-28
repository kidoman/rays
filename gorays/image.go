package main

import (
	"fmt"
	"io"
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

	if err := i.SaveTo(f); err != nil {
		log.Panic(err)
	}
}

func (i *image) SaveTo(w io.Writer) error {
	fmt.Fprintf(w, "P6 %v %v 255 ", i.size, i.size)
	if _, err := w.Write(i.data); err != nil {
		return err
	}
	return nil
}
