# FitPath R8 rules. Flutter and its plugins ship their own consumer rules;
# add app-specific keeps here only when a release build needs them.

# Flutter references Play Core (deferred components) classes it does not
# use in this app; silence the missing-class warnings R8 would fail on.
-dontwarn com.google.android.play.core.**
