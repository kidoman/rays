package main

import (
	"bufio"
	"github.com/kid0m4n/rays/gorays/vector"
	"io"
)

type art []string

func readArt(r io.Reader) art {
	scanner := bufio.NewScanner(r)
	a := make(art, 0)
	for scanner.Scan() {
		a = append(a, scanner.Text())
	}

	return a
}

func (a art) objects() []vector.Vector {
	objects := make([]vector.Vector, 0)
	for j, line := range a {
		for k, column := range line {
			if column != ' ' {
				objects = append(objects, vector.Vector{X: float64(k), Y: 6.5, Z: -float64(len(a)-j) - 1})
			}
		}
	}

	return objects
}
