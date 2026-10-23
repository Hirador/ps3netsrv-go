package viso_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	pkgfs "github.com/xakep666/ps3netsrv-go/pkg/fs"
	"github.com/xakep666/ps3netsrv-go/pkg/fs/viso"
)

// Regression for the PCE-CD crash: webMAN opening a folder-format game whose
// directory name exceeds the 32-byte ISO-9660 volume identifier used to panic
// ("encoded data too large") in the virtual-ISO encoder, killing the whole
// server. The name must now be truncated and the virtual ISO built normally.
func TestVirtualISO_LongFolderName_NoPanic(t *testing.T) {
	const longName = "Akumajou Dracula X - Chi no Rondo (JP) (1993) (Platform Adventure) (PC Engine CD)"
	if len(longName) <= 32 {
		t.Fatalf("test name is not long enough to exercise the bug")
	}

	root := t.TempDir()
	gameDir := filepath.Join(root, longName)
	require.NoError(t, os.Mkdir(gameDir, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(gameDir, "game.bin"), []byte("dummy"), 0o644))

	fsys := pkgfs.NewFS(
		pkgfs.NewRelaxedSystemRoot(root),
		[]pkgfs.FileOpener{viso.Opener{}},
		nil,
	)

	// "***DVD***/" is the mask webMAN sends to mount a folder as a virtual ISO.
	f, err := (viso.Opener{}).Open(context.Background(), fsys, "***DVD***"+string(filepath.Separator)+longName)
	require.NoError(t, err) // pre-fix: panic "encoded data too large"
	require.NotNil(t, f)
	require.NoError(t, f.Close())
}
