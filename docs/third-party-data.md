# Third-party data

## Open Food Facts

FitPath looks up packaged foods in [Open Food Facts](https://world.openfoodfacts.org) (OFF), a free, community-built food database.

### What we send
- Only the **search text** the user types, or a **barcode**. Never profile, diary or device data.
- A descriptive `User-Agent` (`FitPath/<version> (Android; +https://github.com/cr2551/FitPath)`), as OFF asks of every API client. See `lib/core/network/dio_client.dart`.

### Endpoints used
| Purpose | Endpoint |
|---|---|
| Text search | `GET /cgi/search.pl?search_terms=…&search_simple=1&json=1&fields=…` |
| Product by barcode | `GET /api/v2/product/{barcode}?fields=…` |

Requests ask only for the fields FitPath maps (`OpenFoodFactsClient.fields`).

### Rate limits
OFF currently allows about **100 product reads per minute** and **10 searches per minute** per client. Search must be debounced and only run when local results are insufficient (#14). Never retry in a loop.

### Data quality
OFF data is community-contributed and may be incomplete or wrong:
- Missing nutrients stay **unknown (null)**, never zero.
- The source ("Open Food Facts") is shown next to every result and on food details.
- When a user logs an OFF product, it is cached in `food_items` (keyed by barcode), and the diary entry stores a nutrient snapshot. Later changes upstream never rewrite history.

### Licensing and attribution (check before release)
- The **database** is available under the [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/1-0/). Individual contents are under the Database Contents License.
- Product **images** are CC BY-SA. FitPath does not download images in the MVP.
- **Attribution:** the About screen (#43) and the food details screen must credit "Open Food Facts" with a link.
- Before publishing, re-read the current [OFF terms of use and API documentation](https://world.openfoodfacts.org/data), and confirm the Play Store Data safety answers (#43).
