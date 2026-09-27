package commlink

import (
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"
)

// maxTitleBytes is the longest title MediaWiki stores, in bytes, without its
// namespace.
const maxTitleBytes = 255

// titleInvalidSeq is what MediaWiki's title codec rejects besides single
// characters: a percent-encoded byte, and an HTML entity, which it decodes
// before checking, so one left in a name would name another page.
var titleInvalidSeq = regexp.MustCompile(`%[0-9A-Fa-f]{2}|&[A-Za-z0-9\x{80}-\x{10FFFF}]+;`)

// TitleProblem is why MediaWiki would not store a page name, without its
// namespace, as given, or "" when it would: what Title::newFromText rejects
// (a character outside $wgLegalTitleChars, a percent-encoded byte or HTML
// entity, a relative path, three tildes, more than 255 bytes, a leading
// colon, invalid UTF-8) and the bidirectional marks it strips silently.
func TitleProblem(name string) string {
	switch {
	case strings.TrimSpace(name) == "":
		return "the page name is empty"
	case !utf8.ValidString(name) || strings.ContainsRune(name, utf8.RuneError):
		return "the page name is not valid UTF-8"
	case strings.HasPrefix(name, ":"):
		return "the page name starts with a colon"
	case len(name) > maxTitleBytes:
		return fmt.Sprintf("the page name is %d bytes, over MediaWiki's %d", len(name), maxTitleBytes)
	case strings.Contains(name, "~~~"):
		return "the page name holds three tildes, which MediaWiki reads as a signature"
	case name == "." || name == ".." || strings.HasPrefix(name, "./") || strings.HasPrefix(name, "../") ||
		strings.Contains(name, "/./") || strings.Contains(name, "/../") ||
		strings.HasSuffix(name, "/.") || strings.HasSuffix(name, "/.."):
		return "the page name is a relative path"
	}
	for _, r := range name {
		switch {
		case strings.ContainsRune("#<>[]|{}", r):
			return fmt.Sprintf("the page name holds %q, which MediaWiki forbids in titles", string(r))
		case r < 0x20 || r == 0x7F:
			return fmt.Sprintf("the page name holds the control character U+%04X", r)
		case r == 0x200E || r == 0x200F || (r >= 0x202A && r <= 0x202E):
			return fmt.Sprintf("the page name holds the directional mark U+%04X, which MediaWiki strips", r)
		}
	}
	if m := titleInvalidSeq.FindString(name); m != "" {
		return fmt.Sprintf("the page name holds %q, which MediaWiki forbids in titles", m)
	}
	return ""
}
