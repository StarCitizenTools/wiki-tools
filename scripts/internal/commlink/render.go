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
// image source to its wiki file name; an image without one is left out. An
// image alone is a centred thumb; a slideshow is one <gallery>, or a thumb when
// it shows one image.
func RenderBody(blocks []Block, caser *HeadCaser, file func(src string) string) string {
	var parts []string
	for _, b := range blocks {
		switch b.Kind {
		case Heading:
			eq := strings.Repeat("=", b.Level)
			text := caser.Case(b.Text)
			if b.Name {
				text = caser.Name(b.Text)
			}
			parts = append(parts, fmt.Sprintf("%s %s %s", eq, escapeText(text), eq))
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
			parts = append(parts, thumb(name, b.Caption))
		case Gallery:
			if g := gallery(b.Images, file); g != "" {
				parts = append(parts, g)
			}
		case Rule:
			parts = append(parts, "----")
		case Table:
			parts = append(parts, table(b.Rows))
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

// table renders rows as a wikitable, one cell to a line. A pipe in a cell is
// escaped, since it would end the cell.
func table(rows [][]Cell) string {
	var b strings.Builder
	b.WriteString(`{| class="wikitable"`)
	for _, row := range rows {
		b.WriteString("\n|-")
		for _, c := range row {
			marker := "|"
			if c.Header {
				marker = "!"
			}
			b.WriteString("\n" + strings.TrimRight(marker+" "+strings.ReplaceAll(c.Text, "|", "&#124;"), " "))
		}
	}
	b.WriteString("\n|}")
	return b.String()
}

// thumb renders an image alone: a centred thumb with its caption, if any.
func thumb(name, caption string) string {
	if caption == "" {
		return fmt.Sprintf("[[File:%s|thumb|center]]", name)
	}
	return fmt.Sprintf("[[File:%s|thumb|center|%s]]", name, strings.ReplaceAll(caption, "|", "&#124;"))
}

// gallery renders a slideshow's slides as one <gallery>, leaving out a slide
// without a file name; a slideshow left with one image is a thumb. A caption
// every slide shares is the gallery's caption, given once; otherwise each
// slide keeps its own.
func gallery(slides []Block, file func(src string) string) string {
	var names, captions []string
	for _, s := range slides {
		if name := file(s.Src); name != "" {
			names = append(names, name)
			captions = append(captions, s.Caption)
		}
	}
	switch len(names) {
	case 0:
		return ""
	case 1:
		return thumb(names[0], captions[0])
	}
	for i, c := range captions {
		captions[i] = strings.ReplaceAll(c, "|", "&#124;")
	}
	shared := captions[0]
	for _, c := range captions[1:] {
		if c != shared {
			shared = ""
			break
		}
	}
	var b strings.Builder
	if shared != "" {
		b.WriteString(`<gallery caption="` + strings.ReplaceAll(shared, `"`, "&quot;") + `">`)
	} else {
		b.WriteString("<gallery>")
	}
	for i, name := range names {
		b.WriteString("\nFile:" + name)
		if shared == "" && captions[i] != "" {
			b.WriteString("|" + captions[i])
		}
	}
	b.WriteString("\n</gallery>")
	return b.String()
}

// nameSafe maps each character MediaWiki forbids in a file name to a
// lookalike: those no title may hold, and ':', '/' and '\', which an upload
// would otherwise rewrite, leaving the page naming a file that does not exist.
var nameSafe = strings.NewReplacer(
	"/", "∕", ":", "∶", `\`, "∖",
	"#", "＃", "<", "＜", ">", "＞", "[", "［", "]", "］", "{", "｛", "}", "｝", "|", "｜",
)

// PageFileName is the file a page's wikitext is written to.
func PageFileName(page string) string {
	return nameSafe.Replace(page) + ".wikitext"
}
