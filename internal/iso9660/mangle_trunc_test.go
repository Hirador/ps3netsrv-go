package iso9660

import "testing"

// Regression: a source name longer than the 32-byte volume-identifier field
// must be truncated, not panic the fixed-length encoder ("encoded data too
// large"). This is the PCE-CD folder crash (81-char folder name).
func TestMangleStringDMax_TruncatesLongVolumeID(t *testing.T) {
	long := "Akumajou Dracula X - Chi no Rondo (JP) (1993) (Platform Adventure) (PC Engine CD)"

	// PVD volume identifier: 32 bytes, ASCII.
	got := MangleStringDMax(long, false, 32)
	if len(got) > 32 {
		t.Fatalf("PVD volume id not truncated: got %d bytes", len(got))
	}

	// Joliet volume identifier: 32 bytes, UTF-16BE -> must stay on an even
	// (whole code unit) boundary.
	gotJ := MangleStringDMax(long, true, 32)
	if len(gotJ) > 32 {
		t.Fatalf("joliet volume id not truncated: got %d bytes", len(gotJ))
	}
	if len(gotJ)%2 != 0 {
		t.Fatalf("joliet volume id split a UTF-16 code unit: %d bytes", len(gotJ))
	}

	// And it must actually encode into the fixed 32-byte field without panicking.
	var enc Encoder
	enc.AppendString(string(got), 32, ' ')
	enc.AppendString(string(gotJ), 32, 0)

	// A short name must pass through unchanged.
	if s := MangleStringDMax("SHORT", false, 32); string(s) != "SHORT" {
		t.Fatalf("short name altered: %q", s)
	}
}
