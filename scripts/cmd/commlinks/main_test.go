package main

import "testing"

func TestValidateOnlyRefresh(t *testing.T) {
	for _, c := range []struct {
		name    string
		only    string
		refresh bool
		out     string
		wantErr bool
	}{
		{"neither flag, default out", "", false, defaultOut, false},
		{"only with a scratch out", "16000", false, "out/scratch", false},
		{"only with the default out", "16000", false, defaultOut, true},
		{"refresh needs only", "", true, "out/scratch", true},
		{"refresh with only and a scratch out", "16000", true, "out/scratch", false},
		{"refresh with only but the default out", "16000", true, defaultOut, true},
	} {
		err := validateOnlyRefresh(c.only, c.refresh, c.out)
		if (err != nil) != c.wantErr {
			t.Errorf("%s: validateOnlyRefresh(%q, %v, %q) = %v, want error %v", c.name, c.only, c.refresh, c.out, err, c.wantErr)
		}
	}
}
