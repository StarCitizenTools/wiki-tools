package commlink

// BlockKind is the kind of a body block.
type BlockKind int

const (
	Heading BlockKind = iota
	Paragraph
	List
	Quote
	Image
	Video
	Gallery
	Rule
)

// Block is one unit of a report body, independent of RSI's layout.
type Block struct {
	Kind      BlockKind
	Level     int      // Heading: 2 for "==", 3 for "===".
	Text      string   // Heading: plain text. Paragraph, Quote: inline wikitext.
	Emphasis  bool     // Paragraph: from the closing emphasis article, so never a pseudo-heading.
	Items     []string // List: inline wikitext per item.
	Ordered   bool     // List: numbered.
	Src       string   // Image: absolute URL of the original. Video "file": its URL.
	Caption   string   // Image: inline wikitext, may be empty.
	VideoKind string   // Video: "youtube", "vimeo" or "file".
	VideoID   string   // Video: the YouTube or Vimeo id.
	Images    []Block  // Gallery: a slideshow's slides, each an Image block.
}

// imageBlocks lists every image of blocks in body order, a gallery's slides in
// its place.
func imageBlocks(blocks []Block) []Block {
	var out []Block
	for _, b := range blocks {
		switch b.Kind {
		case Image:
			out = append(out, b)
		case Gallery:
			out = append(out, b.Images...)
		}
	}
	return out
}
