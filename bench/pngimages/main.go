// The images of bench/png.isc and bench/png.c, written by the encoder of
// Go (zlib at its default level, a filter chosen for each row as libpng
// does): a photograph (1920 by 1080, colour: gradients and grain), the
// plate of the gallery (1280 by 1040, colour and alpha: an interface), icons
// (512 by 512, colour and alpha: discs with soft edges on transparency), a
// palette (1024 by 1024, 256 colours).
//
// usage: go run bench/pngimages/main.go PLATE.png OUTDIR
// (PLATE.png: written by `iscc run examples/gallery.isc PLATE.png`)
package main

import (
	"image"
	"image/color"
	"image/png"
	"math"
	"math/rand"
	"os"
	"path/filepath"
)

func save(dir, name string, m image.Image) {
	f, err := os.Create(filepath.Join(dir, name))
	if err != nil {
		panic(err)
	}
	if err := png.Encode(f, m); err != nil {
		panic(err)
	}
	f.Close()
}

func main() {
	dir := os.Args[2]
	r := rand.New(rand.NewSource(7))
	photo := image.NewRGBA(image.Rect(0, 0, 1920, 1080))
	for y := 0; y < 1080; y++ {
		for x := 0; x < 1920; x++ {
			fx, fy := float64(x)/1920, float64(y)/1080
			v := func(a float64) uint8 {
				g := int(a) + r.Intn(13) - 6
				if g < 0 {
					g = 0
				}
				if g > 255 {
					g = 255
				}
				return uint8(g)
			}
			photo.Set(x, y, color.RGBA{v(120 + 100*math.Sin(fx*5+fy*2)), v(90 + 80*math.Cos(fx*3-fy*4)), v(60 + 120*fy), 255})
		}
	}
	save(dir, "photo.png", photo)
	f, err := os.Open(os.Args[1])
	if err != nil {
		panic(err)
	}
	plate, err := png.Decode(f)
	if err != nil {
		panic(err)
	}
	f.Close()
	save(dir, "plate.png", plate)
	icons := image.NewNRGBA(image.Rect(0, 0, 512, 512))
	for y := 0; y < 512; y++ {
		for x := 0; x < 512; x++ {
			cx, cy := float64(x%64)-31.5, float64(y%64)-31.5
			d := math.Sqrt(cx*cx+cy*cy) - 24
			a := math.Max(0, math.Min(1, 0.5-d))
			k := (x/64 + y/64*8) * 37
			icons.Set(x, y, color.NRGBA{uint8(k), uint8(255 - k%256), uint8(k * 3), uint8(a * 255)})
		}
	}
	save(dir, "icons.png", icons)
	pal := make(color.Palette, 256)
	for i := range pal {
		pal[i] = color.RGBA{uint8(i), uint8(255 - i), uint8(i * 7), 255}
	}
	paletted := image.NewPaletted(image.Rect(0, 0, 1024, 1024), pal)
	for y := 0; y < 1024; y++ {
		for x := 0; x < 1024; x++ {
			paletted.SetColorIndex(x, y, uint8((x/16+y/16+r.Intn(3))%256))
		}
	}
	save(dir, "palette.png", paletted)
}
