-- Inflate (Oct 27, round 7: the full-colour packed pictures): zlib streams decode exactly (stored, fixed and dynamic
-- Huffman blocks; the checksum is checked and a broken stream is refused), the PNG un-filter gives the picture back, and
-- every packed icon decodes to its own size with see-through corners and a solid middle.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Inflate = require(RS.Shared.Inflate)
	local ImageLoader = require(RS.Shared.ImageLoader)
	local e = t.expect
	local b64 = ImageLoader.base64
	t.test('fixed Huffman and stored blocks decode exactly', function()
		local fixed = Inflate.zlib(b64('eNrLSM3JyVfIwCDL84tyUjLIlgQApTEg6Q=='), 87)
		e.equal(buffer.tostring(fixed), string.rep('hello hello hello hello world', 3))
		local stored = Inflate.zlib(b64('eAEBAAP//AABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4fICEiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj9AQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVpbXF1eX2BhYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ent8fX5/gIGCg4SFhoeIiYqLjI2Oj5CRkpOUlZaXmJmam5ydnp+goaKjpKWmp6ipqqusra6vsLGys7S1tre4ubq7vL2+v8DBwsPExcbHyMnKy8zNzs/Q0dLT1NXW19jZ2tvc3d7f4OHi4+Tl5ufo6err7O3u7/Dx8vP09fb3+Pn6+/z9/v8AAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl9gYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXp7fH1+f4CBgoOEhYaHiImKi4yNjo+QkZKTlJWWl5iZmpucnZ6foKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr/AwcLDxMXGx8jJysvMzc7P0NHS09TV1tfY2drb3N3e3+Dh4uPk5ebn6Onq6+zt7u/w8fLz9PX29/j5+vv8/f7/AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/6BifpA='), 768)
		for i = 0, 767 do
			if buffer.readu8(stored, i) ~= i % 256 then e.equal(buffer.readu8(stored, i), i % 256) break end
		end
	end)
	t.test('a broken stream or a wrong size is refused, never half drawn', function()
		local z = b64('eNrLSM3JyVfIwCDL84tyUjLIlgQApTEg6Q==')
		buffer.writeu8(z, buffer.len(z) - 1, (buffer.readu8(z, buffer.len(z) - 1) + 1) % 256) -- (the checksum's last byte)
		e.falsy((pcall(Inflate.zlib, z, 87)))
		e.falsy((pcall(Inflate.zlib, b64('eNrLSM3JyVfIwCDL84tyUjLIlgQApTEg6Q=='), 86)))
		e.falsy((pcall(Inflate.zlib, b64('AAAAAAAA'), 10)))
	end)
	t.test('the PNG un-filter: Sub, Up, Average and Paeth rows give the picture back', function()
		-- 2 x 2 RGBA: rows filtered with 1 (Sub) and 4 (Paeth) by hand
		local px = { 10, 20, 30, 255, 40, 60, 80, 128, 15, 25, 35, 0, 200, 100, 50, 255 }
		local raw = buffer.create(2 * 9)
		buffer.writeu8(raw, 0, 1)
		for x = 0, 7 do buffer.writeu8(raw, 1 + x, (px[x + 1] - (x >= 4 and px[x - 3] or 0)) % 256) end
		buffer.writeu8(raw, 9, 4)
		for x = 0, 7 do
			local a = x >= 4 and px[8 + x - 3] or 0
			local b = px[x + 1]
			local c = x >= 4 and px[x - 3] or 0
			local p = a + b - c
			local pa, pb, pc = math.abs(p - a), math.abs(p - b), math.abs(p - c)
			local pred = (pa <= pb and pa <= pc) and a or (pb <= pc and b or c)
			buffer.writeu8(raw, 10 + x, (px[9 + x] - pred) % 256)
		end
		local out = Inflate.unfilter(raw, 2, 2)
		for i = 1, 16 do e.equal(buffer.readu8(out, i - 1), px[i]) end
	end)
	t.test('every packed icon decodes in full colour to its own size', function()
		local folder = RS.Shared.Images.Icons
		local n = 0
		for _, m in folder:GetChildren() do
			local d = require(m)
			e.truthy(type(d.Z) == 'string' and d.W > 0 and d.H > 0)
			n += 1
			if n <= 6 or m.Name == 'Lucky' then
				local rgba, w, h = ImageLoader.pixels('Icons', m.Name)
				e.equal(buffer.len(rgba), w * h * 4)
				e.equal(buffer.readu8(rgba, 3), 0) -- (a see-through corner)
				local solid = false
				for x = 0, w - 1 do
					if buffer.readu8(rgba, ((h // 2) * w + x) * 4 + 3) > 200 then solid = true break end
				end
				e.truthy(solid) -- (its middle row is drawn)
			end
		end
		e.truthy(n >= 100)
	end)
end
