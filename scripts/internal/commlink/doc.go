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
)

// Block is one unit of a report body, independent of RSI's layout.
type Block struct {
	Kind      BlockKind
	Level     int      // Heading: 2 for "==", 3 for "===".
	Text      string   // Heading: plain text. Paragraph, Quote: inline wikitext.
	Items     []string // List: inline wikitext per item.
	Ordered   bool     // List: numbered.
	Src       string   // Image: absolute URL of the original. Video "file": its URL.
	Caption   string   // Image: inline wikitext, may be empty.
	VideoKind string   // Video: "youtube", "vimeo" or "file".
	VideoID   string   // Video: the YouTube or Vimeo id.
}
