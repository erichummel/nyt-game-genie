package main

import (
	"cmp"
	"flag"
	"fmt"
	"io"
	"os"
	"slices"
	"sort"
	"strings"
)

var solutions = make(map[string]bool)

func main() {
	letters := flag.String("letters", "", "letters")
	maxDepth := flag.Int("max", 3, "max search depth")
	dictionaryPath := flag.String("dictionary", "", "dictionary path")

	flag.Parse()

	var dictionary []byte
	var err error
	fi, _ := os.Stdin.Stat()

	if (fi.Mode() & os.ModeCharDevice) == 0 {
		dictionary, err = io.ReadAll(os.Stdin)

		if err != nil {
			panic("error reading stdin: " + err.Error())
		}
	} else if len(*dictionaryPath) != 0 {
		path := *dictionaryPath
		dictionary, err = os.ReadFile(path)

		if err != nil {
			panic("error loading dictionary from path provided: " + err.Error())
		}
	} else {
		panic("no dictionary provided")
	}

	words := wordsFromBytes(dictionary)

	letterBoxWords := make([]string, 0)
	letterBoxWords = validWords([]rune(*letters), words, "", []rune{}, letterBoxWords)
	solve(letterBoxWords, []rune(*letters), []string{}, []string{}, 0, *maxDepth)

	solutionKeys := make([]string, 0, len(solutions))
	for key := range solutions {
		solutionKeys = append(solutionKeys, key)
	}

	solutionKeys = leastToMost(solutionKeys)
	for _, solution := range solutionKeys {
		fmt.Println(solution)
	}
	fmt.Println("Valid words found: ", len(letterBoxWords))
	fmt.Println("Solutions found: ", len(solutions))
}

func solutionLength(solution string) (length int) {
	return len(solution)
}

func leastToMost(solutions []string) []string {
	sort.Slice(solutions, func(i, j int) bool {
		return solutionLength(solutions[i]) < solutionLength(solutions[j])
	})

	return solutions
}

func wordsFromBytes(byteWords []byte) []string {
	return strings.Split(string(byteWords), "\n")
}

func wordsStartingWith(startingWith string, words []string) []string {
	matches := []string{}
	for _, word := range words {
		if len(word) == 0 {
			continue
		}

		if len(word) >= len(startingWith) && word[0:len(startingWith)] == startingWith {
			matches = append(matches, word)
		}
	}

	return matches
}

func splitLetters(letters []rune) (sides [][]rune) {
	var thisSide = make([]rune, 0)
	sides = make([][]rune, 0)
	for i, letter := range letters {
		thisSide = append(thisSide, letter)

		if (i+1)%3 == 0 && len(thisSide) > 0 {
			sides = append(sides, thisSide)
			thisSide = make([]rune, 0)
		}
	}
	return sides
}

func validWords(letters []rune, words []string, needle string, except []rune, found []string) []string {
	sides := splitLetters(letters)
	if len(words) == 0 {
		return found
	}

	for _, thisSide := range sides {
		if slices.Equal(thisSide, except) {
			continue
		}

		for _, letter := range thisSide {
			search := strings.Join([]string{needle, string(letter)}, "")
			matches := wordsStartingWith(search, words)
			leafIndex := slices.Index(matches, search)

			if leafIndex != -1 && len(matches[leafIndex]) >= 3 {
				found = append(found, matches[leafIndex])

				matches = append(matches[:leafIndex], matches[leafIndex+1:]...)
			}

			found = validWords(letters, matches, search, thisSide, found)
		}
	}
	slices.SortFunc(found, func(a, b string) int {
		return cmp.Compare(len(a), len(b))
	})

	return found
}

func solve(words []string, letters []rune, soFar []string, skip []string, depth int, maxDepth int) {
	if isSolution(soFar, letters) {
		solutions[strings.Join(soFar, ", ")] = true
		return
	}

	if depth >= maxDepth {
		return
	}

	for _, word := range words {
		if slices.Contains(skip, word) {
			continue
		}

		soFarCopy := append(soFar, word)
		skipCopy := append(skip, word)

		solve(
			wordsStartingWith(string(word[len(word)-1]), words),
			letters,
			soFarCopy,
			skipCopy,
			depth+1,
			maxDepth,
		)
	}
}

func isSolution(selected []string, letters []rune) bool {
	return slices.Equal(
		uniqRunes([]rune(strings.Join(selected, ""))),
		uniqRunes(letters),
	)
}

func uniqRunes(allRunes []rune) []rune {
	slices.Sort(allRunes)
	last := '*'
	uniq := []rune{}

	for _, elem := range allRunes {
		if elem != last {
			uniq = append(uniq, elem)
			last = elem
		}
	}
	return uniq
}
