package commlink

import (
	"fmt"
	"regexp"
	"strings"
)

var (
	youtubeIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)
	vimeoIDPattern   = regexp.MustCompile(`^[0-9]+$`)
)

// PageMeta is what the infobox shows.
type PageMeta struct {
	RSITitle, URL, Series, Type, Date string
}

// Infobox is the page's {{CommLink}} call, in the parameter order of the
// template's documentation. RSITitle is escaped; other fields are passed as-is.
func Infobox(m PageMeta) string {
	title := strings.ReplaceAll(escapeText(m.RSITitle), "|", "&#124;")
	return fmt.Sprintf("{{CommLink\n| title = %s\n| url = %s\n| image =\n| series = %s\n| type = %s\n| publicationdate = %s\n}}\n",
		title, m.URL, m.Series, m.Type, m.Date)
}

// RenderBody writes blocks as wikitext, one blank line apart. file maps an
// image source to its wiki file name; an image without one is left out.
func RenderBody(blocks []Block, caser *HeadCaser, file func(src string) string) string {
	var parts []string
	for _, b := range blocks {
		switch b.Kind {
		case Heading:
			eq := strings.Repeat("=", b.Level)
			parts = append(parts, fmt.Sprintf("%s %s %s", eq, escapeText(caser.Case(b.Text)), eq))
		case Paragraph:
			parts = append(parts, lineSafe(b.Text))
		case Quote:
			parts = append(parts, "<blockquote>"+b.Text+"</blockquote>")
		case List:
			marker := "*"
			if b.Ordered {
				marker = "#"
			}
			lines := make([]string, len(b.Items))
			for i, it := range b.Items {
				lines[i] = marker + " " + it
			}
			parts = append(parts, strings.Join(lines, "\n"))
		case Image:
			name := file(b.Src)
			if name == "" {
				continue
			}
			if b.Caption != "" {
				parts = append(parts, fmt.Sprintf("[[File:%s|thumb|center|%s]]", name, strings.ReplaceAll(b.Caption, "|", "&#124;")))
			} else {
				parts = append(parts, fmt.Sprintf("[[File:%s|center|frameless|800px]]", name))
			}
		case Video:
			switch b.VideoKind {
			case "youtube":
				if youtubeIDPattern.MatchString(b.VideoID) {
					parts = append(parts, "{{#ev:youtube|"+b.VideoID+"}}")
				}
			case "vimeo":
				if vimeoIDPattern.MatchString(b.VideoID) {
					parts = append(parts, "{{#ev:vimeo|"+b.VideoID+"}}")
				}
			case "file":
				parts = append(parts, "["+b.Src+" Watch the video]")
			}
		}
	}
	return strings.Join(parts, "\n\n") + "\n"
}

// PageFileName is the file a page's wikitext is written to.
func PageFileName(page string) string {
	return strings.ReplaceAll(page, "/", "∕") + ".wikitext"
}
