// respond, the DTO shape in Go: for each request build the typed response
// object -- an id, a user name, a list of line items -- render it as JSON,
// and throw both away. A port of goose/respond.goose and
// rust/respond_dto.rs: same xorshift input, same checksum.
//
// What a Go service would write: a string per name and per sku, a []Item, a
// strings.Builder for the rendering and strconv for the numbers. Each of
// those is a heap allocation the collector reclaims.
package main

import (
	"fmt"
	"strconv"
	"strings"
)

const N = 1600000 // BENCH_N

func xsNext(x uint64) uint64 {
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	return x
}

func xsMod(x uint64, k int64) int64 { return int64(x % uint64(k)) }

type Item struct {
	Sku   string
	Qty   int64
	Price int64
}

type Resp struct {
	ID    int64
	User  string
	Items []Item
}

// A user name of 3..10 letters; one in eight carries a quote or a backslash
// so the escaping path in the renderer is real.
func nameOf(seed uint64) string {
	var s strings.Builder
	r := xsNext(seed)
	n := 3 + xsMod(r, 8)
	odd := xsMod(r>>8, 8) == 0
	for i := int64(0); i < n; i++ {
		r = xsNext(r)
		if odd && i == 1 {
			if xsMod(r, 2) == 0 {
				s.WriteByte('"')
			} else {
				s.WriteByte('\\')
			}
		} else {
			s.WriteByte(byte('a' + xsMod(r, 26)))
		}
	}
	return s.String()
}

// A stock keeping unit: two letters and four digits.
func skuOf(seed uint64) string {
	var s strings.Builder
	r := xsNext(seed)
	s.WriteByte(byte('A' + xsMod(r, 26)))
	s.WriteByte(byte('A' + xsMod(r>>8, 26)))
	for i := 0; i < 4; i++ {
		r = xsNext(r)
		s.WriteByte(byte('0' + xsMod(r, 10)))
	}
	return s.String()
}

func makeItems(seed uint64, n int64) []Item {
	var t []Item
	r := seed
	for i := int64(0); i < n; i++ {
		r = xsNext(r)
		t = append(t, Item{Sku: skuOf(r), Qty: 1 + xsMod(r>>8, 5), Price: 100 + xsMod(r>>16, 99900)})
	}
	return t
}

func emitStr(out *strings.Builder, s string) {
	out.WriteByte('"')
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '"' || c == '\\' {
			out.WriteByte('\\')
		}
		out.WriteByte(c)
	}
	out.WriteByte('"')
}

func render(r *Resp) string {
	var out strings.Builder
	out.WriteString(`{"id":`)
	out.WriteString(strconv.FormatInt(r.ID, 10))
	out.WriteString(`,"user":`)
	emitStr(&out, r.User)
	out.WriteString(`,"items":[`)
	var total int64
	for i, it := range r.Items {
		if i > 0 {
			out.WriteByte(',')
		}
		out.WriteString(`{"sku":`)
		emitStr(&out, it.Sku)
		out.WriteString(`,"qty":`)
		out.WriteString(strconv.FormatInt(it.Qty, 10))
		out.WriteString(`,"price":`)
		out.WriteString(strconv.FormatInt(it.Price, 10))
		out.WriteByte('}')
		total += it.Qty * it.Price
	}
	out.WriteString(`],"total":`)
	out.WriteString(strconv.FormatInt(total, 10))
	out.WriteByte('}')
	return out.String()
}

func fnv(s string) uint64 {
	h := uint64(14695981039346656037)
	for i := 0; i < len(s); i++ {
		h = (h ^ uint64(s[i])) * 1099511628211
	}
	return h
}

// One request: the response object and its rendering are both temporaries.
func handle(seed uint64) (uint64, int64) {
	r := xsNext(seed)
	n := 1 + xsMod(r, 8)
	resp := Resp{ID: xsMod(r>>4, 1000000), User: nameOf(r >> 8), Items: makeItems(r>>16, n)}
	out := render(&resp)
	return fnv(out), int64(len(out))
}

func main() {
	seed := uint64(12345)
	var h uint64
	var bytes int64
	for i := int64(0); i < N; i++ {
		seed = xsNext(seed)
		hh, l := handle(seed)
		h ^= hh*31 + uint64(i)
		bytes += l
	}
	fmt.Println(N)
	fmt.Println(bytes)
	fmt.Println(h)
}
