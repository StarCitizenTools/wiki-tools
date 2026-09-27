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
	Table
)

// Block is one unit of a report body, independent of RSI's layout.
type Block struct {
	Kind      BlockKind
	Level     int      // Heading: 2 for "==", 3 for "===".
	Name      bool     // Heading: names a ship or feature (a Q&A section header), so title-cased.
	Text      string   // Heading: plain text. Paragraph, Quote: inline wikitext.
	Emphasis  bool     // Paragraph: bold by RSI's styling (the closing emphasis article, a segment title's subtitle), so never a pseudo-heading.
	Items     []string // List: inline wikitext per item.
	Ordered   bool     // List: numbered.
	Src       string   // Image: absolute URL of the original. Video "file": its URL.
	Caption   string   // Image: inline wikitext, may be empty.
	VideoKind string   // Video: "youtube", "vimeo" or "file".
	VideoID   string   // Video: the YouTube or Vimeo id.
	Images    []Block  // Gallery: a slideshow's slides, each an Image block.
	Rows      [][]Cell // Table: its rows, each a run of cells.
}

// Cell is one table cell: inline wikitext, whether it is a header cell, and
// the columns and rows it spans past its own (0 for one).
type Cell struct {
	Text             string
	Header           bool
	Colspan, Rowspan int
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
