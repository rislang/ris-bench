# Crystal: iyi/respond_dto.iyi without its module and import lines.
#   crystal build --release crystal/respond_dto.cr -o respond_crystal
#
# respond, the DTO shape: for each request build the typed response object
# -- an id, a user name, a list of line items -- render it as JSON, and throw
# both away. A port of goose/respond.goose and
# rust/respond_dto.rs: same xorshift input, same checksum.
#
# This is what an iyi program would write without thinking about memory: a
# String per name and per sku, an Array of Item structs, a String::Builder for
# the rendering. Every one of those is a GC allocation, and all of it is
# garbage before the next request starts.



N = 1600000_i64 # BENCH_N

def xs_next(x : UInt64) : UInt64
  v = x
  v = v ^ (v << 13)
  v = v ^ (v >> 7)
  v = v ^ (v << 17)
  v
end

def xs_mod(x : UInt64, k : Int64) : Int64
  (x % k.to_u64).to_i64
end

struct Item
  getter sku : String
  getter qty : Int64
  getter price : Int64

  def initialize(@sku : String, @qty : Int64, @price : Int64)
  end
end

struct Resp
  getter id : Int64
  getter user : String
  getter items : Array(Item)

  def initialize(@id : Int64, @user : String, @items : Array(Item))
  end
end

# A user name of 3..10 letters; one in eight carries a quote or a backslash
# so the escaping path in the renderer is real.
def name_of(seed : UInt64) : String
  r = xs_next(seed)
  n = 3_i64 + xs_mod(r, 8_i64)
  odd = xs_mod(r >> 8, 8_i64) == 0_i64
  String.build do |s|
    i = 0_i64
    while i < n
      r = xs_next(r)
      if odd && i == 1_i64
        s.write_byte(xs_mod(r, 2_i64) == 0_i64 ? 34_u8 : 92_u8)
      else
        s.write_byte((97_i64 + xs_mod(r, 26_i64)).to_u8)
      end
      i += 1_i64
    end
  end
end

# A stock keeping unit: two letters and four digits.
def sku_of(seed : UInt64) : String
  r = xs_next(seed)
  String.build do |s|
    s.write_byte((65_i64 + xs_mod(r, 26_i64)).to_u8)
    s.write_byte((65_i64 + xs_mod(r >> 8, 26_i64)).to_u8)
    i = 0
    while i < 4
      r = xs_next(r)
      s.write_byte((48_i64 + xs_mod(r, 10_i64)).to_u8)
      i += 1
    end
  end
end

def make_items(seed : UInt64, n : Int64) : Array(Item)
  t = [] of Item
  r = seed
  i = 0_i64
  while i < n
    r = xs_next(r)
    t << Item.new(sku_of(r), 1_i64 + xs_mod(r >> 8, 5_i64), 100_i64 + xs_mod(r >> 16, 99900_i64))
    i += 1_i64
  end
  t
end

def emit_str(buf : String::Builder, s : String) : Nil
  buf.write_byte(34_u8)
  s.each_byte do |c|
    buf.write_byte(92_u8) if c == 34_u8 || c == 92_u8
    buf.write_byte(c)
  end
  buf.write_byte(34_u8)
end

def render(r : Resp) : String
  String.build do |buf|
    buf << "{\"id\":" << r.id
    buf << ",\"user\":"
    emit_str(buf, r.user)
    buf << ",\"items\":["
    total = 0_i64
    first = true
    r.items.each do |it|
      buf.write_byte(44_u8) unless first
      first = false
      buf << "{\"sku\":"
      emit_str(buf, it.sku)
      buf << ",\"qty\":" << it.qty << ",\"price\":" << it.price
      buf.write_byte(125_u8)
      total += it.qty * it.price
    end
    buf << "],\"total\":" << total
    buf.write_byte(125_u8)
  end
end

def fnv(s : String) : UInt64
  h = 14695981039346656037_u64
  s.each_byte { |c| h = (h ^ c.to_u64) &* 1099511628211_u64 }
  h
end

seed = 12345_u64
h = 0_u64
bytes = 0_i64
i = 0_i64
while i < N
  seed = xs_next(seed)
  r = xs_next(seed)
  n = 1_i64 + xs_mod(r, 8_i64)
  resp = Resp.new(xs_mod(r >> 4, 1000000_i64), name_of(r >> 8), make_items(r >> 16, n))
  buf = render(resp)
  h = h ^ (fnv(buf) &* 31_u64 &+ i.to_u64)
  bytes += buf.bytesize.to_i64
  i += 1_i64
end
puts N
puts bytes
puts h
