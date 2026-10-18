// respond_dto.rs with every string and list in a bumpalo arena, reset after
// each request: the per-request arena a Rust service would add by hand.
#[path = "../../bench.rs"]
mod bench;
use bench::*;
use bumpalo::collections::{String, Vec};
use bumpalo::Bump;
use std::fmt::Write;

const N: i64 = 1600000;                   // BENCH_N

struct Item<'b> { sku: String<'b>, qty: i64, price: i64 }
struct Resp<'b> { id: i64, user: String<'b>, items: Vec<'b, Item<'b>> }

fn name_of(b: &Bump, seed: u64) -> String<'_> {
    let mut s = String::new_in(b);
    let mut r = xs_next(seed);
    let n = 3 + xs_mod(r, 8);
    let odd = xs_mod(r >> 8, 8) == 0;
    for i in 0..n {
        r = xs_next(r);
        if odd && i == 1 { s.push(if xs_mod(r, 2) == 0 { '"' } else { '\\' }); }
        else { s.push((b'a' + xs_mod(r, 26) as u8) as char); }
    }
    s
}

fn sku_of(b: &Bump, seed: u64) -> String<'_> {
    let mut s = String::new_in(b);
    let mut r = xs_next(seed);
    s.push((b'A' + xs_mod(r, 26) as u8) as char);
    s.push((b'A' + xs_mod(r >> 8, 26) as u8) as char);
    for _ in 0..4 { r = xs_next(r); s.push((b'0' + xs_mod(r, 10) as u8) as char); }
    s
}

fn make_items(b: &Bump, seed: u64, n: i64) -> Vec<'_, Item<'_>> {
    let mut t = Vec::new_in(b);
    let mut r = seed;
    for _ in 0..n {
        r = xs_next(r);
        t.push(Item { sku: sku_of(b, r), qty: 1 + xs_mod(r >> 8, 5),
                      price: 100 + xs_mod(r >> 16, 99900) });
    }
    t
}

fn emit_str(out: &mut String<'_>, s: &str) {
    out.push('"');
    for c in s.chars() {
        if c == '"' || c == '\\' { out.push('\\'); }
        out.push(c);
    }
    out.push('"');
}

fn render<'b>(b: &'b Bump, r: &Resp<'_>) -> String<'b> {
    let mut out = String::new_in(b);
    write!(out, "{{\"id\":{}", r.id).unwrap();
    out.push_str(",\"user\":");
    emit_str(&mut out, &r.user);
    out.push_str(",\"items\":[");
    let mut total: i64 = 0;
    for (i, it) in r.items.iter().enumerate() {
        if i > 0 { out.push(','); }
        out.push_str("{\"sku\":");
        emit_str(&mut out, &it.sku);
        write!(out, ",\"qty\":{},\"price\":{}}}", it.qty, it.price).unwrap();
        total += it.qty * it.price;
    }
    write!(out, "],\"total\":{}}}", total).unwrap();
    out
}

fn fnv(s: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for &c in s { h = (h ^ c as u64).wrapping_mul(0x100000001b3); }
    h
}

fn handle(b: &Bump, seed: u64) -> (u64, i64) {
    let r = xs_next(seed);
    let n = 1 + xs_mod(r, 8);
    let resp = Resp { id: xs_mod(r >> 4, 1000000), user: name_of(b, r >> 8),
                      items: make_items(b, r >> 16, n) };
    let out = render(b, &resp);
    (fnv(out.as_bytes()), out.len() as i64)
}

fn main() {
    let mut bump = Bump::new();
    let mut seed: u64 = 12345;
    let mut h: u64 = 0;
    let mut bytes: i64 = 0;
    for i in 0..N {
        seed = xs_next(seed);
        let (hh, l) = handle(&bump, seed);
        bump.reset();
        h ^= hh.wrapping_mul(31).wrapping_add(i as u64);
        bytes += l;
    }
    emit(N);
    emit(bytes);
    println!("{}", h);
}
