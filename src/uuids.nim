import strutils, hashes
import urandom

type
  UUID* = object
    ## 128-bit UUID compliant with RFC-4122
    mostSigBits: int64
    leastSigBits: int64

template toHex(s: string, start: Natural,
               x: BiggestInt, len: Positive) =
  const HexChars = "0123456789abcdef"
  var n = x
  for j in countdown(len - 1, 0):
    s[start + j] = HexChars[n and 0xF]
    n = n shr 4
    # handle negative overflow
    if n == 0 and x < 0: n = -1

proc `$`*(uuid: UUID): string =
  ## Returns a string representation of the UUID in canonical form.
  result = newString(36)
  toHex(result, 0, uuid.mostSigBits shr 32, 8)
  result[8] = '-'
  toHex(result, 9, uuid.mostSigBits shr 16, 4)
  result[13] = '-'
  toHex(result, 14, uuid.mostSigBits, 4)
  result[18] = '-'
  toHex(result, 19, uuid.leastSigBits shr 48, 4)
  result[23] = '-'
  toHex(result, 24, uuid.leastSigBits, 12)

proc hash*(uuid: UUID): Hash =
  ## Computes hash of the specified UUID.
  result = uuid.mostSigBits.hash() !& uuid.leastSigBits.hash()
  result = !$result

proc `==`*(x, y: UUID): bool =
  ## Returns ``true`` when the specified UUIDs are equal, ``false`` otherwise.
  x.mostSigBits == y.mostSigBits and x.leastSigBits == y.leastSigBits

proc genUUID*(): UUID =
  ## Returns a random (v4) UUID.
  ## Uses random values obtained from system source (e.g. urandom).
  ## In the future this will use a cryptographically secure PRNG for efficiency.
  var randBytes: array[16, uint8] = urandom(16)
  copyMem(addr result.mostSigBits, addr randBytes[0], 8)
  copyMem(addr result.leastSigBits, addr randBytes[8], 8)

  # set version to 4
  result.mostSigBits = (result.mostSigBits and 0xFFFFFFFFFFFF0FFF'i64) or
                       0x0000000000004000'i64
  # set IETF variant
  result.leastSigBits = (result.leastSigBits and 0x3FFFFFFFFFFFFFFF'i64) or
                        0x8000000000004000'i64

proc toUUID*(s: string): UUID {.raises: [ValueError].} =
  ## Converts string representation of an UUID to UUID object.
  ## Raises ``ValueError`` if invalid format is provided.
  let parts = s.split('-')
  if parts.len != 5:
    raise newException(ValueError,
                       "UUID must consist of 5 parts separated with `-`")
  var mostSigBits: int64 = parseHexInt(parts[0])
  mostSigBits = mostSigBits shl 16
  mostSigBits = mostSigBits or parseHexInt(parts[1])
  mostSigBits = mostSigBits shl 16
  mostSigBits = mostSigBits or parseHexInt(parts[2])

  var leastSigBits: int64 = parseHexInt(parts[3])
  leastSigBits = leastSigBits shl 48
  leastSigBits = leastSigBits or parseHexInt(parts[4])

  result = UUID(mostSigBits: mostSigBits, leastSigBits: leastSigBits)

when isMainModule:
  let uuid = genUUID()
  let uuidStr = $uuid
  assert(uuidStr.len == 36)
  assert(uuidStr[14] == '4') # version
  assert(uuidStr[19] in {'8', '9', 'a', 'b'}) # variant (2 bits)
  assert(uuidStr.toUUID() == uuid)
  assert(uuidStr.toUUID().hash() == uuid.hash())
