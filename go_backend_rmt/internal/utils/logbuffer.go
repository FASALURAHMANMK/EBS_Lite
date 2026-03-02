package utils

import (
	"bytes"
	"sync"
)

var defaultLogBuffer *LineBuffer

// LineBuffer stores the last N log lines written to it.
type LineBuffer struct {
	mu       sync.Mutex
	maxLines int
	pending  bytes.Buffer
	lines    []string
}

func NewLineBuffer(maxLines int) *LineBuffer {
	if maxLines <= 0 {
		maxLines = 200
	}
	return &LineBuffer{
		maxLines: maxLines,
		lines:    make([]string, 0, maxLines),
	}
}

func InitDefaultLogBuffer(maxLines int) *LineBuffer {
	defaultLogBuffer = NewLineBuffer(maxLines)
	return defaultLogBuffer
}

func DefaultLogLines(limit int) []string {
	if defaultLogBuffer == nil {
		return nil
	}
	return defaultLogBuffer.Lines(limit)
}

func (b *LineBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()

	n, _ := b.pending.Write(p)
	for {
		data := b.pending.Bytes()
		idx := bytes.IndexByte(data, '\n')
		if idx < 0 {
			break
		}
		line := string(data[:idx])
		b.pending.Next(idx + 1)
		if line == "" {
			continue
		}
		b.lines = append(b.lines, line)
		if len(b.lines) > b.maxLines {
			extra := len(b.lines) - b.maxLines
			b.lines = b.lines[extra:]
		}
	}
	return n, nil
}

func (b *LineBuffer) Lines(limit int) []string {
	b.mu.Lock()
	defer b.mu.Unlock()

	if limit <= 0 || limit >= len(b.lines) {
		out := make([]string, len(b.lines))
		copy(out, b.lines)
		return out
	}
	out := make([]string, limit)
	copy(out, b.lines[len(b.lines)-limit:])
	return out
}
