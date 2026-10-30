-- Inflate (Oct 27, round 7, OUR_UI_AUDIT A1/A2: the packed pictures were 192 px, 256 colours and dithered, so they
-- looked blurry and grainy): a small zlib / DEFLATE decoder (RFC 1950 / 1951) and the PNG row un-filter, so a packed
-- picture can be stored as its PNG's own compressed pixels (lossless, full colour, every edge kept) and turned back into
-- RGBA bytes in game. Pure Luau on buffers; it pauses a frame (task.wait) every YieldEvery output bytes when it runs in a
-- coroutine that can yield, so a big picture never freezes the game. Every error says what was wrong (a bad stream is
-- refused, never half drawn): the zlib stream's Adler-32 is checked.
--   Inflate.zlib(input: buffer, outSize: number) -> buffer      the decompressed bytes (exactly outSize of them)
--   Inflate.unfilter(raw: buffer, w, h) -> buffer               PNG filtered rows (RGBA, 8 bit) -> w * h * 4 RGBA bytes
local Inflate = {}
Inflate.YieldEvery = 262144

local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift

-- the length and distance codes' bases and extra bits (RFC 1951, 3.2.5)
local LBASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LEXT = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DBASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
local DEXT = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CLORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

-- A decoding table from code lengths (lengths[i + 1] for symbol i): an array indexed by the next `bits` input bits
-- (LSB first) + 1, each entry symbol * 16 + its length. Returns the table and its bit width.
local function build(lengths, n)
	local count = table.create(16, 0)
	local maxLen = 0
	for i = 1, n do
		local l = lengths[i]
		if l > 0 then
			count[l] += 1
			if l > maxLen then maxLen = l end
		end
	end
	if maxLen == 0 then return table.create(2, 0), 1 end
	-- the canonical codes (RFC 1951 3.2.2): the first code of each length
	local nc = table.create(16, 0)
	local code = 0
	for bits = 1, 15 do
		code = lshift(code + (bits > 1 and count[bits - 1] or 0), 1)
		nc[bits] = code
	end
	local size = lshift(1, maxLen)
	local tbl = table.create(size, 0)
	for sym = 0, n - 1 do
		local l = lengths[sym + 1]
		if l > 0 then
			local c = nc[l]
			nc[l] = c + 1
			-- reverse the l bits of c (deflate sends codes most significant bit first, read LSB first)
			local r = 0
			for _ = 1, l do
				r = bor(lshift(r, 1), band(c, 1))
				c = rshift(c, 1)
			end
			local entry = sym * 16 + l
			local step = lshift(1, l)
			for i = r, size - 1, step do tbl[i + 1] = entry end
		end
	end
	return tbl, maxLen
end

local FIXED_L, FIXED_LBITS, FIXED_D, FIXED_DBITS
do
	local l = table.create(288, 0)
	for i = 1, 144 do l[i] = 8 end
	for i = 145, 256 do l[i] = 9 end
	for i = 257, 280 do l[i] = 7 end
	for i = 281, 288 do l[i] = 8 end
	FIXED_L, FIXED_LBITS = build(l, 288)
	local d = table.create(30, 5)
	FIXED_D, FIXED_DBITS = build(d, 30)
end

-- Decompresses a zlib stream into a new buffer of exactly outSize bytes.
function Inflate.zlib(inp: buffer, outSize: number): buffer
	local inLen = buffer.len(inp)
	assert(inLen >= 6, 'inflate: stream too short')
	local cmf, flg = buffer.readu8(inp, 0), buffer.readu8(inp, 1)
	assert(band(cmf, 15) == 8, 'inflate: not deflate')
	assert((cmf * 256 + flg) % 31 == 0, 'inflate: bad zlib header')
	assert(band(flg, 32) == 0, 'inflate: preset dictionary not supported')
	local out = buffer.create(outSize)
	local pos, bitBuf, bitCnt, o = 2, 0, 0, 0
	local pause = coroutine.isyieldable() and type(task) == 'table' and task.wait or nil
	local nextYield = Inflate.YieldEvery

	local function need(n)
		while bitCnt < n do
			if pos < inLen then
				bitBuf = bor(bitBuf, lshift(buffer.readu8(inp, pos), bitCnt))
				pos += 1
			elseif bitCnt == 0 and n > 0 then
				error('inflate: out of input')
			else
				return -- (the stream's last bits: what is left is zeros)
			end
			bitCnt += 8
		end
	end
	local function getBits(n)
		if n == 0 then return 0 end
		need(n)
		if bitCnt < n then error('inflate: out of input') end
		local v = band(bitBuf, lshift(1, n) - 1)
		bitBuf = rshift(bitBuf, n)
		bitCnt -= n
		return v
	end
	local function decodeSym(tbl, bits)
		need(bits)
		local e = tbl[band(bitBuf, lshift(1, bits) - 1) + 1]
		local l = band(e, 15)
		if l == 0 or l > bitCnt then error('inflate: bad code') end
		bitBuf = rshift(bitBuf, l)
		bitCnt -= l
		return rshift(e, 4)
	end

	local final = 0
	repeat
		final = getBits(1)
		local kind = getBits(2)
		if kind == 0 then
			-- stored: skip to the byte boundary, give back the whole bytes still held, then LEN, NLEN and the bytes
			local drop = bitCnt % 8
			bitBuf, bitCnt = rshift(bitBuf, drop), bitCnt - drop
			pos -= bitCnt // 8
			bitBuf, bitCnt = 0, 0
			assert(pos + 4 <= inLen, 'inflate: out of input')
			local len = buffer.readu16(inp, pos)
			local nlen = buffer.readu16(inp, pos + 2)
			assert(len + nlen == 65535, 'inflate: bad stored length')
			pos += 4
			assert(pos + len <= inLen, 'inflate: out of input')
			assert(o + len <= outSize, 'inflate: output too long')
			buffer.copy(out, o, inp, pos, len)
			pos += len
			o += len
		elseif kind == 1 or kind == 2 then
			local lt, lbits, dt, dbits
			if kind == 1 then
				lt, lbits, dt, dbits = FIXED_L, FIXED_LBITS, FIXED_D, FIXED_DBITS
			else
				local hlit = getBits(5) + 257
				local hdist = getBits(5) + 1
				local hclen = getBits(4) + 4
				local cl = table.create(19, 0)
				for i = 1, hclen do cl[CLORDER[i] + 1] = getBits(3) end
				local ct, cbits = build(cl, 19)
				local lengths = table.create(hlit + hdist, 0)
				local i = 1
				while i <= hlit + hdist do
					local sym = decodeSym(ct, cbits)
					if sym < 16 then
						lengths[i] = sym
						i += 1
					else
						local rep, val
						if sym == 16 then
							assert(i > 1, 'inflate: repeat with no length')
							val, rep = lengths[i - 1], 3 + getBits(2)
						elseif sym == 17 then
							val, rep = 0, 3 + getBits(3)
						else
							val, rep = 0, 11 + getBits(7)
						end
						assert(i + rep - 1 <= hlit + hdist, 'inflate: too many lengths')
						for _ = 1, rep do
							lengths[i] = val
							i += 1
						end
					end
				end
				local ll, dl = table.create(hlit, 0), table.create(hdist, 0)
				for k = 1, hlit do ll[k] = lengths[k] end
				for k = 1, hdist do dl[k] = lengths[hlit + k] end
				lt, lbits = build(ll, hlit)
				dt, dbits = build(dl, hdist)
			end
			while true do
				local sym = decodeSym(lt, lbits)
				if sym < 256 then
					if o >= outSize then error('inflate: output too long') end
					buffer.writeu8(out, o, sym)
					o += 1
				elseif sym == 256 then
					break
				else
					local li = sym - 256
					assert(li <= 29, 'inflate: bad length code')
					local len = LBASE[li] + getBits(LEXT[li])
					local ds = decodeSym(dt, dbits)
					assert(ds <= 29, 'inflate: bad distance code')
					local dist = DBASE[ds + 1] + getBits(DEXT[ds + 1])
					assert(dist <= o, 'inflate: distance too far back')
					assert(o + len <= outSize, 'inflate: output too long')
					if dist >= len then
						buffer.copy(out, o, out, o - dist, len)
					else
						for k = 0, len - 1 do buffer.writeu8(out, o + k, buffer.readu8(out, o - dist + k)) end
					end
					o += len
				end
				if pause and o >= nextYield then
					nextYield += Inflate.YieldEvery
					pause()
				end
			end
		else
			error('inflate: bad block type')
		end
	until final == 1
	assert(o == outSize, 'inflate: output too short (' .. o .. ' of ' .. outSize .. ')')
	-- the Adler-32 of the output (the stream's last 4 bytes, after the byte boundary)
	local drop = bitCnt % 8
	bitBuf, bitCnt = rshift(bitBuf, drop), bitCnt - drop
	pos -= bitCnt // 8
	if pos + 4 <= inLen then
		local want = buffer.readu8(inp, pos) * 16777216 + buffer.readu8(inp, pos + 1) * 65536 + buffer.readu8(inp, pos + 2) * 256 + buffer.readu8(inp, pos + 3)
		local a, b = 1, 0
		local k = 0
		while k < outSize do
			local stop = math.min(outSize, k + 3800)
			for j = k, stop - 1 do
				a += buffer.readu8(out, j)
				b += a
			end
			a %= 65521
			b %= 65521
			k = stop
		end
		assert(b * 65536 + a == want, 'inflate: checksum mismatch')
	end
	return out
end

-- PNG scanlines (each row: one filter byte, then w * 4 bytes, RGBA 8 bit) -> the plain RGBA rows, w * h * 4 bytes.
function Inflate.unfilter(raw: buffer, w: number, h: number): buffer
	local stride = w * 4
	assert(buffer.len(raw) == h * (stride + 1), 'unfilter: wrong size')
	local out = buffer.create(h * stride)
	local pause = coroutine.isyieldable() and type(task) == 'table' and task.wait or nil
	for y = 0, h - 1 do
		local f = buffer.readu8(raw, y * (stride + 1))
		local src = y * (stride + 1) + 1
		local dst = y * stride
		local up = dst - stride
		if f == 0 then
			buffer.copy(out, dst, raw, src, stride)
		elseif f == 1 then
			for x = 0, stride - 1 do
				local left = x >= 4 and buffer.readu8(out, dst + x - 4) or 0
				buffer.writeu8(out, dst + x, (buffer.readu8(raw, src + x) + left) % 256)
			end
		elseif f == 2 then
			for x = 0, stride - 1 do
				local above = y > 0 and buffer.readu8(out, up + x) or 0
				buffer.writeu8(out, dst + x, (buffer.readu8(raw, src + x) + above) % 256)
			end
		elseif f == 3 then
			for x = 0, stride - 1 do
				local left = x >= 4 and buffer.readu8(out, dst + x - 4) or 0
				local above = y > 0 and buffer.readu8(out, up + x) or 0
				buffer.writeu8(out, dst + x, (buffer.readu8(raw, src + x) + (left + above) // 2) % 256)
			end
		elseif f == 4 then
			for x = 0, stride - 1 do
				local a = x >= 4 and buffer.readu8(out, dst + x - 4) or 0
				local b = y > 0 and buffer.readu8(out, up + x) or 0
				local c = (x >= 4 and y > 0) and buffer.readu8(out, up + x - 4) or 0
				local p = a + b - c
				local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
				local pred = (pa <= pb and pa <= pc) and a or (pb <= pc and b or c)
				buffer.writeu8(out, dst + x, (buffer.readu8(raw, src + x) + pred) % 256)
			end
		else
			error('unfilter: bad filter ' .. f)
		end
		if pause and y % 64 == 63 then pause() end
	end
	return out
end

return Inflate
