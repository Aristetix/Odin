package rand

import "core:intrinsics"

Rand :: struct {
	state: u64,
	inc:   u64,
	is_system: bool,
}


@(private)
global_rand := create(u64(intrinsics.read_cycle_counter()))

set_global_seed :: proc(seed: u64) {
	init(&global_rand, seed)
}

create :: proc(seed: u64) -> Rand {
	r: Rand
	init(&r, seed)
	return r
}

init :: proc(r: ^Rand, seed: u64) {
	r.state = 0
	r.inc = (seed << 1) | 1
	_random(r)
	r.state += seed
	_random(r)
}

init_as_system :: proc(r: ^Rand) {
	if !#defined(_system_random) {
		panic(#procedure + " is not supported on this platform yet")
	}
	r.state = 0
	r.inc   = 0
	r.is_system = true
}

@(private)
_random :: proc(r: ^Rand) -> u32 {
	r := r
	if r == nil {
		// NOTE(bill, 2020-09-07): Do this so that people can
		// enforce the global random state if necessary with `nil`
		r = &global_rand
	}
	when #defined(_system_random) {
		if r.is_system {
			return _system_random()
		}
	}

	old_state := r.state
	r.state = old_state * 6364136223846793005 + (r.inc|1)
	xor_shifted := u32(((old_state>>18) ~ old_state) >> 27)
	rot := u32(old_state >> 59)
	return (xor_shifted >> rot) | (xor_shifted << ((-rot) & 31))
}

uint32 :: proc(r: ^Rand = nil) -> u32 { return _random(r) }

uint64 :: proc(r: ^Rand = nil) -> u64 {
	a := u64(_random(r))
	b := u64(_random(r))
	return (a<<32) | b
}

uint128 :: proc(r: ^Rand = nil) -> u128 {
	a := u128(_random(r))
	b := u128(_random(r))
	c := u128(_random(r))
	d := u128(_random(r))
	return (a<<96) | (b<<64) | (c<<32) | d
}

int31  :: proc(r: ^Rand = nil) -> i32  { return i32(uint32(r) << 1 >> 1) }
int63  :: proc(r: ^Rand = nil) -> i64  { return i64(uint64(r) << 1 >> 1) }
int127 :: proc(r: ^Rand = nil) -> i128 { return i128(uint128(r) << 1 >> 1) }

int31_max :: proc(n: i32, r: ^Rand = nil) -> i32 {
	if n <= 0 {
		panic("Invalid argument to int31_max")
	}
	if n&(n-1) == 0 {
		return int31(r) & (n-1)
	}
	max := i32((1<<31) - 1 - (1<<31)%u32(n))
	v := int31(r)
	for v > max {
		v = int31(r)
	}
	return v % n
}

int63_max :: proc(n: i64, r: ^Rand = nil) -> i64 {
	if n <= 0 {
		panic("Invalid argument to int63_max")
	}
	if n&(n-1) == 0 {
		return int63(r) & (n-1)
	}
	max := i64((1<<63) - 1 - (1<<63)%u64(n))
	v := int63(r)
	for v > max {
		v = int63(r)
	}
	return v % n
}

int127_max :: proc(n: i128, r: ^Rand = nil) -> i128 {
	if n <= 0 {
		panic("Invalid argument to int127_max")
	}
	if n&(n-1) == 0 {
		return int127(r) & (n-1)
	}
	max := i128((1<<127) - 1 - (1<<127)%u128(n))
	v := int127(r)
	for v > max {
		v = int127(r)
	}
	return v % n
}

int_max :: proc(n: int, r: ^Rand = nil) -> int {
	if n <= 0 {
		panic("Invalid argument to int_max")
	}
	when size_of(int) == 4 {
		return int(int31_max(i32(n), r))
	} else {
		return int(int63_max(i64(n), r))
	}
}

// Uniform random distribution [0, 1)
float64 :: proc(r: ^Rand = nil) -> f64 { return f64(int63_max(1<<53, r)) / (1 << 53) }
// Uniform random distribution [0, 1)
float32 :: proc(r: ^Rand = nil) -> f32 { return f32(float64(r)) }

float64_range :: proc(lo, hi: f64, r: ^Rand = nil) -> f64 { return (hi-lo)*float64(r) + lo }
float32_range :: proc(lo, hi: f32, r: ^Rand = nil) -> f32 { return (hi-lo)*float32(r) + lo }

read :: proc(p: []byte, r: ^Rand = nil) -> (n: int) {
	pos := i8(0)
	val := i64(0)
	for n = 0; n < len(p); n += 1 {
		if pos == 0 {
			val = int63(r)
			pos = 7
		}
		p[n] = byte(val)
		val >>= 8
		pos -= 1
	}
	return
}

// perm returns a slice of n ints in a pseudo-random permutation of integers in the range [0, n)
perm :: proc(n: int, r: ^Rand = nil, allocator := context.allocator) -> []int {
	m := make([]int, n, allocator)
	for i := 0; i < n; i += 1 {
		j := int_max(i+1, r)
		m[i] = m[j]
		m[j] = i
	}
	return m
}


shuffle :: proc(array: $T/[]$E, r: ^Rand = nil) {
	n := i64(len(array))
	if n < 2 {
		return
	}

	for i := i64(0); i < n; i += 1 {
		j := int63_max(n, r)
		array[i], array[j] = array[j], array[i]
	}
}

// Returns a random element from the given slice
choice :: proc(array: $T/[]$E, r: ^Rand = nil) -> (res: E) {
	n := i64(len(array))
	if n < 1 {
		return E{}
	}
	return array[int63_max(n, r)]
}