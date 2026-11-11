// The reference of the decoder of PNG of the library (tests/png_check.isc):
// each file named decoded by the package image/png of Go, its pixels as
// 0xAARRGGBB, 8 bits a channel, not premultiplied (a sample of 16 bits: its
// high byte), and their FNV-1a of 64 bits (each pixel a word: h = (h ^ p) *
// 0x100000001b3, written in decimal); a file refused: its name and "error".
//
// usage: go run tools/pngref/main.go FILE...
package main

import (
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
)

func pixel(c color.Color) uint32 {
	pack := func(a, r, g, b uint8) uint32 {
		return uint32(a)<<24 | uint32(r)<<16 | uint32(g)<<8 | uint32(b)
	}
	switch v := c.(type) {
	case color.NRGBA:
		return pack(v.A, v.R, v.G, v.B)
	case color.NRGBA64:
		return pack(uint8(v.A>>8), uint8(v.R>>8), uint8(v.G>>8), uint8(v.B>>8))
	case color.RGBA:
		if v.A != 0xFF {
			panic("an RGBA not opaque")
		}
		return pack(v.A, v.R, v.G, v.B)
	case color.RGBA64:
		if v.A != 0xFFFF {
			panic("an RGBA64 not opaque")
		}
		return pack(0xFF, uint8(v.R>>8), uint8(v.G>>8), uint8(v.B>>8))
	case color.Gray:
		return pack(0xFF, v.Y, v.Y, v.Y)
	case color.Gray16:
		y := uint8(v.Y >> 8)
		return pack(0xFF, y, y, y)
	}
	panic(fmt.Sprintf("a colour of type %T", c))
}

func main() {
	for _, name := range os.Args[1:] {
		f, err := os.Open(name)
		if err != nil {
			panic(err)
		}
		m, err := png.Decode(f)
		f.Close()
		if err != nil {
			fmt.Printf("%s error\n", filepath.Base(name))
			continue
		}
		b := m.Bounds()
		h := uint64(0xcbf29ce484222325)
		for y := b.Min.Y; y < b.Max.Y; y++ {
			for x := b.Min.X; x < b.Max.X; x++ {
				h = (h ^ uint64(pixel(m.At(x, y)))) * 0x100000001b3
			}
		}
		var _ image.Image = m
		fmt.Printf("%s %d %d %d\n", filepath.Base(name), b.Dx(), b.Dy(), h)
	}
}
