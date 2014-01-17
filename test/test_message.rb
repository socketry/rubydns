require 'rubydns'

class MessageTest < Test::Unit::TestCase
	def setup
	end
	
	def teardown
	end

  def hex2bin(hexstring)
    ret = "\x00" * (hexstring.length / 2)
    ret.force_encoding("BINARY")
    offset = 0
    while offset < hexstring.length
      hex_byte = hexstring[offset..(offset+1)]
      ret.setbyte(offset/2, hex_byte.to_i(16))
      offset += 2
    end
    ret
  end

	def test_good_decode
    data = hex2bin("1d008180000100080000000103777777057961686f6f03636f6d0000010001c00c000500010000012c000f0666642d667033037767310162c010c02b000500010000012c00090664732d667033c032c046000500010000003c00150e64732d616e792d6670332d6c666203776131c036c05b000500010000012c00120f64732d616e792d6670332d7265616cc06ac07c000100010000003c0004628afc1ec07c000100010000003c0004628bb495c07c000100010000003c0004628bb718c07c000100010000003c0004628afd6d0000291000000000000000")
		
    decoded = RubyDNS.decode_message(data)
    assert_equal(RubyDNS::Message, decoded.class)
    assert_equal(0x1d00, decoded.id)
    assert_equal(1, decoded.question.count)
    assert_equal(8, decoded.answer.count)
    assert_equal(0, decoded.authority.count)
    assert_equal(1, decoded.additional.count)
	end
	
	def test_bad_AAAA_length
    data = hex2bin("ea9e8180000100010000000108626169636169636e03636f6d00001c0001c00c001c00010000011e000432177b770000291000000000000000")
		
    assert_raise(Resolv::DNS::DecodeError) do
      RubyDNS.decode_message(data)
    end
	end
end
