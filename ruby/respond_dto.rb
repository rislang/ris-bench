# respond, the DTO shape in idiomatic Ruby: a String per name and per sku,
# an Array of Item structs, the JSON built into a String. Same xorshift
# input and checksum as the other versions; 64-bit wrapping by masking.
N = 1_600_000
MASK = 0xFFFF_FFFF_FFFF_FFFF

def xs_next(x)
  x ^= (x << 13) & MASK
  x ^= x >> 7
  x ^= (x << 17) & MASK
  x
end

LOWER = "abcdefghijklmnopqrstuvwxyz"
UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
DIGITS = "0123456789"

Item = Struct.new(:sku, :qty, :price)
Resp = Struct.new(:id, :user, :items)

# A user name of 3..10 letters; one in eight carries a quote or a backslash.
def name_of(seed)
  r = xs_next(seed)
  n = 3 + r % 8
  odd = (r >> 8) % 8 == 0
  s = +""
  n.times do |i|
    r = xs_next(r)
    s << (odd && i == 1 ? (r % 2 == 0 ? '"' : "\\") : LOWER[r % 26])
  end
  s
end

# A stock keeping unit: two letters and four digits.
def sku_of(seed)
  r = xs_next(seed)
  s = +""
  s << UPPER[r % 26] << UPPER[(r >> 8) % 26]
  4.times do
    r = xs_next(r)
    s << DIGITS[r % 10]
  end
  s
end

def make_items(seed, n)
  r = seed
  Array.new(n) do
    r = xs_next(r)
    Item.new(sku_of(r), 1 + (r >> 8) % 5, 100 + (r >> 16) % 99_900)
  end
end

def emit_str(out, s)
  out << '"'
  s.each_char do |c|
    out << "\\" if c == '"' || c == "\\"
    out << c
  end
  out << '"'
end

def render(resp)
  out = +"{\"id\":#{resp.id},\"user\":"
  emit_str(out, resp.user)
  out << ',"items":['
  total = 0
  resp.items.each_with_index do |it, i|
    out << "," if i > 0
    out << '{"sku":'
    emit_str(out, it.sku)
    out << ",\"qty\":#{it.qty},\"price\":#{it.price}}"
    total += it.qty * it.price
  end
  out << "],\"total\":#{total}}"
end

def fnv(s)
  h = 0xcbf29ce484222325
  s.each_byte { |c| h = ((h ^ c) * 0x100000001b3) & MASK }
  h
end

seed = 12345
h = 0
bytes = 0
N.times do |i|
  seed = xs_next(seed)
  r = xs_next(seed)
  n = 1 + r % 8
  resp = Resp.new((r >> 4) % 1_000_000, name_of(r >> 8), make_items(r >> 16, n))
  out = render(resp)
  h ^= ((fnv(out) * 31) & MASK) + i & MASK
  bytes += out.bytesize
end
puts N, bytes, h
