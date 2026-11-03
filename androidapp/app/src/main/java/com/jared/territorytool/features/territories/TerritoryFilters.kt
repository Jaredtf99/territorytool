package com.jared.territorytool.features.territories

import androidx.annotation.StringRes
import com.jared.territorytool.R

enum class TerritoryFilter(@StringRes val title: Int, val backendValue: String) {
    All(R.string.territories_filter_all, "all"),
    Free(R.string.territories_filter_free, "available"),
    InUse(R.string.territories_filter_in_use, "assigned"),
    Attention(R.string.territories_filter_attention, "attention"),
}

enum class TerritorySortOption(val code: Int, @StringRes val title: Int) {
    Name(1, R.string.territories_sort_name),
    Code(2, R.string.territories_sort_code),
    GivenDate(3, R.string.territories_sort_given_date),
    Nearest(4, R.string.territories_sort_nearest),
}

enum class TerritoryDrawerDetent { Collapsed, Medium }
