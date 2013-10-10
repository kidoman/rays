package main

import (
	"encoding/json"
	"log"
	"os"
)

type result struct {
	Samples []float64
}

func (r result) Average() float64 {
	sum := 0.0
	for _, s := range r.Samples {
		sum += s
	}
	return sum / float64(len(r.Samples))
}

func (r result) Save() {
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
		r.Samples,
	}

	enc := json.NewEncoder(f)
	enc.Encode(data)
}
