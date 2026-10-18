package com.modu.reader;

import android.icu.text.BreakIterator;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

/** Local ICU fallback for WebViews that do not expose Intl.Segmenter. */
public final class ReaderWordSelection {
    private ReaderWordSelection() {}

    public static List<List<Integer>> paragraphBounds(String text, String localeTag) {
        if (text == null || text.isEmpty() || text.length() > 65536 ||
                (localeTag != null && localeTag.length() > 128)) return null;
        Locale locale = localeTag == null ? Locale.getDefault() : Locale.forLanguageTag(localeTag);
        if (locale.getLanguage().isEmpty()) locale = Locale.getDefault();
        BreakIterator iterator = BreakIterator.getWordInstance(locale);
        iterator.setText(text);
        List<List<Integer>> words = new ArrayList<>();
        int start = iterator.first();
        for (int end = iterator.next(); end != BreakIterator.DONE; start = end, end = iterator.next()) {
            if (iterator.getRuleStatus() >= BreakIterator.WORD_NONE_LIMIT)
                words.add(Arrays.asList(start, end));
        }
        return words;
    }

    public static List<Integer> bounds(String text, Integer offset, String localeTag) {
        if (text == null || text.isEmpty() || text.length() > 65536 ||
                offset == null || offset < 0 || offset > text.length() ||
                (localeTag != null && localeTag.length() > 128)) return null;
        Locale locale = localeTag == null ? Locale.getDefault() : Locale.forLanguageTag(localeTag);
        if (locale.getLanguage().isEmpty()) locale = Locale.getDefault();
        BreakIterator iterator = BreakIterator.getWordInstance(locale);
        iterator.setText(text);
        int index = offset == text.length() ? offset - 1 : offset;
        int end = iterator.following(index);
        if (end == BreakIterator.DONE || iterator.getRuleStatus() < BreakIterator.WORD_NONE_LIMIT)
            return null; // Whitespace, punctuation and emoji are not words.
        int start = iterator.previous();
        return start >= 0 && start <= index && index < end ? Arrays.asList(start, end) : null;
    }
}
