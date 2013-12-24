package main

import (
	"encoding/json"
	"log"
	"os"
)

type results []float64

func (r results) Sum() (sum float64) {
	for _, s := range r {
		sum += s
	}

	return
}

func (r results) Average() float64 {
	return r.Sum() / float64(len(r))
}

func (r results) Save() {
	f, err := os.Create(*resultfile)
	if err != nil {
		log.Panic(err)
	}
	defer f.Close()

	data := struct {
		Average float64   `json:"average"`
		Samples []float64 `json:"samples"`
	}{
		r.Average(),
		r,
	}

	enc := json.NewEncoder(f)
	enc.Encode(data)
}
