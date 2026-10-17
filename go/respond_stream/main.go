// respond, the streaming shape in Go: the same responses as respond_dto,
// rendered straight into one reused []byte as they are generated, with no
// response object in between. The RNG is consumed in the same order, so the
// bytes and the checksum match. The expert row: no allocation per request.
package main

import (
	"fmt"
	"strconv"
)

const N = 1600000 // BENCH_N

func xsNext(x uint64) uint64 {
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	return x
}

func xsMod(x uint64, k int64) int64 { return int64(x % uint64(k)) }

func emitName(out []byte, seed uint64) []byte {
	r := xsNext(seed)
	n := 3 + xsMod(r, 8)
	odd := xsMod(r>>8, 8) == 0
	out = append(out, '"')
	for i := int64(0); i < n; i++ {
		r = xsNext(r)
		if odd && i == 1 {
			out = append(out, '\\')
			if xsMod(r, 2) == 0 {
				out = append(out, '"')
			} else {
				out = append(out, '\\')
			}
		} else {
			out = append(out, byte('a'+xsMod(r, 26)))
		}
	}
	return append(out, '"')
}

func emitSku(out []byte, seed uint64) []byte {
	r := xsNext(seed)
	out = append(out, '"', byte('A'+xsMod(r, 26)), byte('A'+xsMod(r>>8, 26)))
	for i := 0; i < 4; i++ {
		r = xsNext(r)
		out = append(out, byte('0'+xsMod(r, 10)))
	}
	return append(out, '"')
}

func fnv(s []byte) uint64 {
	h := uint64(14695981039346656037)
	for _, c := range s {
		h = (h ^ uint64(c)) * 1099511628211
	}
	return h
}

func main() {
	out := make([]byte, 0, 4096)
	seed := uint64(12345)
	var h uint64
	var bytes int64
	for i := int64(0); i < N; i++ {
		seed = xsNext(seed)
		r0 := xsNext(seed)
		n := 1 + xsMod(r0, 8)
		out = out[:0]
		out = append(out, `{"id":`...)
		out = strconv.AppendInt(out, xsMod(r0>>4, 1000000), 10)
		out = append(out, `,"user":`...)
		out = emitName(out, r0>>8)
		out = append(out, `,"items":[`...)
		var total int64
		r := r0 >> 16
		for k := int64(0); k < n; k++ {
			r = xsNext(r)
			if k > 0 {
				out = append(out, ',')
			}
			qty := 1 + xsMod(r>>8, 5)
			price := 100 + xsMod(r>>16, 99900)
			out = append(out, `{"sku":`...)
			out = emitSku(out, r)
			out = append(out, `,"qty":`...)
			out = strconv.AppendInt(out, qty, 10)
			out = append(out, `,"price":`...)
			out = strconv.AppendInt(out, price, 10)
			out = append(out, '}')
			total += qty * price
		}
		out = append(out, `],"total":`...)
		out = strconv.AppendInt(out, total, 10)
		out = append(out, '}')
		h ^= fnv(out)*31 + uint64(i)
		bytes += int64(len(out))
	}
	fmt.Println(N)
	fmt.Println(bytes)
	fmt.Println(h)
}
