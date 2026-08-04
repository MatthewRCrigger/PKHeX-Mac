#ifndef PKHEX_NATIVE_H
#define PKHEX_NATIVE_H

#include <stdint.h>

/* C ABI surface exported by PKHeX.Interop (see PKHeX.Interop/*.cs). All handles are opaque
 * non-zero int64 IDs into a managed registry; 0 means "invalid/not found". */

/* --- Save lifecycle --- */
int64_t pkhex_save_load(const uint8_t *data, int32_t length);
void pkhex_save_close(int64_t handle);
int32_t pkhex_save_write(int64_t handle, uint8_t *out_buffer, int32_t out_buffer_length);

int32_t pkhex_save_get_box_count(int64_t handle);
int32_t pkhex_save_get_box_slot_count(int64_t handle);
uint8_t pkhex_save_get_generation(int64_t handle);
/* Display name of this save's game version, e.g. "Crystal", "Platinum", "HeartGold". */
int32_t pkhex_save_get_game_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);

uint16_t pkhex_save_get_max_species_id(int64_t handle);
int32_t pkhex_save_get_dex_seen_count(int64_t handle);
int32_t pkhex_save_get_dex_caught_count(int64_t handle);
uint8_t pkhex_save_has_pokedex(int64_t handle);
int32_t pkhex_save_get_box_name(int64_t handle, int32_t box, uint16_t *out_buffer, int32_t out_buffer_length);

/* Creates a blank-template PKM of the given species (level 1, this save's trainer/language),
 * ready for pkhex_save_set_slot/pkhex_save_set_party_slot. Release with pkhex_pkm_close. */
int64_t pkhex_save_create_blank_pkm(int64_t handle, uint16_t species);

int64_t pkhex_save_get_slot(int64_t handle, int32_t box, int32_t slot);
int32_t pkhex_save_set_slot(int64_t save_handle, int64_t pkm_handle, int32_t box, int32_t slot);
/* Clears a box slot back to empty (species 0). Box slots may have gaps, so no other slots move. */
int32_t pkhex_save_clear_slot(int64_t handle, int32_t box, int32_t slot);

int32_t pkhex_save_get_party_count(int64_t handle);
int64_t pkhex_save_get_party_slot(int64_t handle, int32_t index);
int32_t pkhex_save_set_party_slot(int64_t save_handle, int64_t pkm_handle, int32_t index);
/* Clears a party slot, sliding every following party member down one slot to keep the party
 * contiguous from index 0 (unlike box slots, party slots may never have gaps). */
int32_t pkhex_save_clear_party_slot(int64_t handle, int32_t index);

/* --- PKM lifecycle & fields --- */
void pkhex_pkm_close(int64_t handle);

uint16_t pkhex_pkm_get_species(int64_t handle);
void pkhex_pkm_set_species(int64_t handle, uint16_t species);

uint8_t pkhex_pkm_get_format(int64_t handle);

uint8_t pkhex_pkm_get_level(int64_t handle);
void pkhex_pkm_set_level(int64_t handle, uint8_t level);

uint8_t pkhex_pkm_get_nature(int64_t handle);
void pkhex_pkm_set_nature(int64_t handle, uint8_t nature);

uint8_t pkhex_pkm_get_ball(int64_t handle);
void pkhex_pkm_set_ball(int64_t handle, uint8_t ball);

uint8_t pkhex_pkm_get_gender(int64_t handle);
void pkhex_pkm_set_gender(int64_t handle, uint8_t gender);

uint8_t pkhex_pkm_get_is_shiny(int64_t handle);

/* 1 if this PKM has computed party stats (read from a party slot), 0 if it's a box slot with no
 * "in the field" state. Gate status-condition UI on this. */
uint8_t pkhex_pkm_get_party_stats_present(int64_t handle);

/* Normalized status condition: 0=None, 1=Paralysis, 2=Sleep, 3=Freeze, 4=Burn, 5=Poison. Same
 * values regardless of generation (see PkmExports.cs for how this is normalized/denormalized
 * against the two different raw Status_Condition bit layouts). */
uint8_t pkhex_pkm_get_status_type(int64_t handle);
void pkhex_pkm_set_status_type(int64_t handle, uint8_t status_type);

uint16_t pkhex_pkm_get_held_item(int64_t handle);
void pkhex_pkm_set_held_item(int64_t handle, uint16_t item);

/* Held item display name, resolved through this PKM's own generation (correct for Gen 1-3 saves,
 * which number items differently than the shared/modern id space pkhex_item_get_name assumes). */
int32_t pkhex_pkm_get_held_item_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
/* Display name of an arbitrary item id, resolved the same way — for listing held-item picker
 * candidates (1...pkhex_pkm_get_max_item_id), not just the currently-held item. */
int32_t pkhex_pkm_get_item_name(int64_t handle, uint16_t item, uint16_t *out_buffer, int32_t out_buffer_length);

uint16_t pkhex_pkm_get_ability(int64_t handle);

/* Number of selectable ability slots for this PKM's species/form: 0 (Gen 1-2), 2 (Gen 3-4,
 * Ability1/Ability2 only), or 3 (Gen 5+, adds a Hidden Ability slot). */
int32_t pkhex_pkm_get_ability_count(int64_t handle);
/* Ability ID for slot `index` (0=Ability1, 1=Ability2, 2=Hidden Ability), for building an ability
 * picker's option list alongside pkhex_pkm_get_ability_count. */
uint16_t pkhex_pkm_get_ability_at_index(int64_t handle, int32_t index);
/* Sets this PKM's ability to the one at the given slot index (0=Ability1, 1=Ability2, 2=Hidden
 * Ability), handling every generation's storage quirks correctly (PID re-rolls where needed). */
void pkhex_pkm_set_ability_index(int64_t handle, int32_t index);

/* --- Met/Egg info --- */
uint16_t pkhex_pkm_get_met_location(int64_t handle);
void pkhex_pkm_set_met_location(int64_t handle, uint16_t location);

uint16_t pkhex_pkm_get_egg_location(int64_t handle);
void pkhex_pkm_set_egg_location(int64_t handle, uint16_t location);

uint8_t pkhex_pkm_get_met_level(int64_t handle);
void pkhex_pkm_set_met_level(int64_t handle, uint8_t level);

uint8_t pkhex_pkm_get_fateful_encounter(int64_t handle);
void pkhex_pkm_set_fateful_encounter(int64_t handle, uint8_t value);

/* 1 if this PKM's format tracks a Met Date (Gen 4+) / Egg Location+Date (Gen 4+) / has any Is-Egg
 * concept at all (Gen 2+ — Gen 1 predates Day Care/eggs entirely). Gate the corresponding UI on
 * these rather than on the value being zero/null, since zero is also a legitimate reading. */
uint8_t pkhex_pkm_get_supports_met_date(int64_t handle);
uint8_t pkhex_pkm_get_supports_egg_location(int64_t handle);
uint8_t pkhex_pkm_get_supports_is_egg(int64_t handle);

/* Met/Egg date as (year, month, day) with a full 4-digit year. Returns 0 (all-zero out params) if
 * this format doesn't support the date or the stored fields don't form a valid date. Pass year 0
 * to pkhex_pkm_set_met_date/set_egg_date to clear the date. */
uint8_t pkhex_pkm_get_met_date(int64_t handle, int32_t *year, int32_t *month, int32_t *day);
void pkhex_pkm_set_met_date(int64_t handle, int32_t year, int32_t month, int32_t day);
uint8_t pkhex_pkm_get_egg_date(int64_t handle, int32_t *year, int32_t *month, int32_t *day);
void pkhex_pkm_set_egg_date(int64_t handle, int32_t year, int32_t month, int32_t day);

uint8_t pkhex_pkm_get_is_egg(int64_t handle);
/* 1 if this PKM currently is an egg OR was originally received as one and has since hatched
 * (IsEgg || EggDay != 0) — i.e. it has legitimate egg history worth showing egg location/date for,
 * as opposed to a plain wild-caught Pokemon with no egg history at all. */
uint8_t pkhex_pkm_get_was_egg(int64_t handle);
/* Toggling to true also renames to the localized egg name, resets the hatch counter, clears the
 * Met Date, and seeds a default Egg Location/Level (see PkmExports.cs's PkmSetIsEgg remarks for
 * exactly what this does and does not replicate from PKHeX.WinForms' fuller encounter-aware
 * handler). Toggling to false restores CurrentFriendship to the species' base friendship. */
void pkhex_pkm_set_is_egg(int64_t handle, uint8_t value);

/* Candidate Met/Egg location ids for this PKM's current version+context (egg=1 for the Egg
 * Location list, 0 for Met Location), for building a location picker — mirrors
 * GameInfo.GetLocationList's per-version partitioning. Enumerate ids via
 * pkhex_pkm_get_location_id_at_index(0..<count), then resolve display names via
 * pkhex_pkm_get_location_name. */
int32_t pkhex_pkm_get_location_count(int64_t handle, uint8_t egg);
uint16_t pkhex_pkm_get_location_id_at_index(int64_t handle, uint8_t egg, int32_t index);
/* Display name for a location id, resolved for this PKM's version+context (the same numeric id
 * can mean different places in different games/generations). Empty string if not present in this
 * PKM's current location list. */
int32_t pkhex_pkm_get_location_name(int64_t handle, uint16_t location_id, uint8_t egg, uint16_t *out_buffer, int32_t out_buffer_length);

/* Type IDs (see pkhex_type_get_name); Type2 equals Type1 for single-type species. */
uint8_t pkhex_pkm_get_type1(int64_t handle);
uint8_t pkhex_pkm_get_type2(int64_t handle);

uint16_t pkhex_pkm_get_move(int64_t handle, int32_t index);
void pkhex_pkm_set_move(int64_t handle, int32_t index, uint16_t move);

/* Type ID (see pkhex_type_get_name) of a move ID, resolved for this PKM's game context — a
 * handful of moves' types differ across generations, so this isn't a static move->type table. */
uint8_t pkhex_pkm_get_move_type(int64_t handle, uint16_t move);

int32_t pkhex_pkm_get_iv(int64_t handle, int32_t stat);
void pkhex_pkm_set_iv(int64_t handle, int32_t stat, int32_t value);

int32_t pkhex_pkm_get_ev(int64_t handle, int32_t stat);
void pkhex_pkm_set_ev(int64_t handle, int32_t stat, int32_t value);

int32_t pkhex_pkm_get_move_pp(int64_t handle, int32_t index);
int32_t pkhex_pkm_get_move_pp_max(int64_t handle, int32_t index);

/* Base max PP (0 PP Ups) for an arbitrary move ID, independent of any equipped slot — what a
 * newly-selected move's PP would be, since selecting a move resets PP Ups to 0. */
int32_t pkhex_pkm_get_move_base_pp(int64_t handle, uint16_t move);

/* UTF-16 code units; call once with NULL buffer to size, again to fill. */
int32_t pkhex_pkm_get_nickname(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
void pkhex_pkm_set_nickname(int64_t handle, const uint16_t *name, int32_t length);

int32_t pkhex_pkm_get_sprite_file_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
/* Newer/higher-coverage artwork set (species up to #1025, vs. the sprite set's ~#905 cutoff).
 * Not guaranteed to exist in the shipped asset catalog for every form/shiny combination —
 * fall back to a form/shiny-stripped variant, then to pkhex_pkm_get_sprite_file_name, if missing. */
int32_t pkhex_pkm_get_artwork_file_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);

int32_t pkhex_pkm_get_max_nickname_length(int64_t handle);

/* --- Name lookups (current display language; UTF-16, size-then-fill like above) --- */
int32_t pkhex_species_get_name(uint16_t species, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_move_get_name(uint16_t move, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_nature_get_name(uint8_t nature, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_item_get_name(uint16_t item, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_type_get_name(uint8_t type, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_ability_get_name(uint16_t ability, uint16_t *out_buffer, int32_t out_buffer_length);
/* Short flavor-text description of an Ability ID, e.g. "Powers up moves of the same type."; empty
 * if unknown/not yet catalogued (see Scripts/generate_ability_descriptions.py). */
int32_t pkhex_ability_get_description(uint16_t ability, uint16_t *out_buffer, int32_t out_buffer_length);
/* Ball display name (see PKHeX.Core's Ball enum), e.g. "Poké Ball", "Ultra Ball". */
int32_t pkhex_ball_get_name(uint8_t ball, uint16_t *out_buffer, int32_t out_buffer_length);

/* --- Cross-save / cross-generation conversion ---
 * For dragging or pasting a Pokemon from one open save into another of a different generation
 * (e.g. Gen 3 -> Gen 4, or 3DS Virtual Console Gen 1/2 -> Gen 7). Same-generation moves don't need
 * these — just pkhex_save_set_slot/pkhex_save_set_party_slot directly. */

/* Converts a PKM to the format required by dest_save_handle (its PKMType). Returns a handle to the
 * converted PKM (release with pkhex_pkm_close), ready to place into dest_save_handle via
 * pkhex_save_set_slot/pkhex_save_set_party_slot, or 0 if no legal conversion path exists (wrong
 * direction, incompatible species/form, or a GB-era language mismatch) — call
 * pkhex_pkm_get_convert_error for why. Does not mutate pkm_handle or dest_save_handle. */
int64_t pkhex_pkm_convert_to_save(int64_t pkm_handle, int64_t dest_save_handle);

/* 1 if pkhex_pkm_convert_to_save would succeed for this pair, 0 otherwise — cheap to call
 * speculatively (e.g. during a drag, before a drop) without allocating a result handle. */
uint8_t pkhex_pkm_can_convert_to_save(int64_t pkm_handle, int64_t dest_save_handle);

/* Human-readable reason conversion would fail for this pair ("" if it would succeed), matching
 * PKHeX.WinForms' wording. Size-then-fill like other string exports. */
int32_t pkhex_pkm_get_convert_error(int64_t pkm_handle, int64_t dest_save_handle, uint16_t *out_buffer, int32_t out_buffer_length);

/* --- Legality --- */
int32_t pkhex_pkm_is_legal(int64_t handle);
int32_t pkhex_pkm_get_legality_report(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length, uint8_t verbose);

/* Human-readable legality reasons, one per line, empty if legal (verbose off; same text as
 * pkhex_pkm_get_legality_report(verbose:0)). Intended for showing just the first line in a UI banner. */
int32_t pkhex_pkm_get_legality_lines(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);

/* Individual legality check results (both valid and invalid — filter on severity), for a granular
 * "here's what's wrong" UI beyond pkhex_pkm_get_legality_lines' flat text report. Enumerate via
 * pkhex_pkm_get_legality_result_count/severity/identifier/message (0..<count). */
int32_t pkhex_pkm_get_legality_result_count(int64_t handle);
/* -1 = Invalid, 0 = Fishy, 1 = Valid (matches PKHeX.Core's Severity enum values exactly). */
int8_t pkhex_pkm_get_legality_result_severity(int64_t handle, int32_t index);
/* Category ordinal (matches PKHeX.Core's CheckIdentifier enum) — group results by this, and use it
 * to decide whether pkhex_pkm_apply_legality_fix has a quick-fix for this category. */
uint8_t pkhex_pkm_get_legality_result_identifier(int64_t handle, int32_t index);
/* Fully-resolved human-readable message for this result (item/species/move names substituted in).
 * Size-then-fill like other string exports. */
int32_t pkhex_pkm_get_legality_result_message(int64_t handle, int32_t index, uint16_t *out_buffer, int32_t out_buffer_length);

/* Applies a curated, mechanically-safe quick-fix for the legality result at `index`, if one exists
 * for its category (currently: Trainer, Memory, Handler, Ball — see PkmApplyLegalityFix's remarks
 * in LegalityExports.cs). There is no general "make legal" engine in PKHeX.Core to wrap (that's a
 * separate closed-source tool); this only covers common, unambiguous repairs. Returns 1 if applied,
 * 0 if no quick-fix exists for this category, -1 on invalid handles/index. */
int32_t pkhex_pkm_apply_legality_fix(int64_t pkm_handle, int64_t save_handle, int32_t index);

/* Programmatic name of a CheckIdentifier ordinal (e.g. "Trainer", "Memory", "Ball", "Handler") —
 * matches the enum member name exactly. Lets callers switch on category by name instead of
 * hardcoding ordinals that would silently break if PKHeX.Core reorders the enum. */
int32_t pkhex_check_identifier_get_name(uint8_t identifier, uint16_t *out_buffer, int32_t out_buffer_length);

/* Highest move ID valid for this PKM's format, for a fallback "all moves" picker. */
uint16_t pkhex_pkm_get_max_move_id(int64_t handle);

/* Highest item ID valid for this PKM's format, for a held-item picker. */
uint16_t pkhex_pkm_get_max_item_id(int64_t handle);

/* The move IDs this PKM can currently legally learn, for building a move picker. */
int32_t pkhex_pkm_get_legal_move_count(int64_t handle);
uint16_t pkhex_pkm_get_legal_move(int64_t handle, int32_t move_list_index);

/* --- Per-Pokemon Original Trainer / Handling Trainer / Memories ---
 * Distinct from the save-level "Trainer info" section below, which is the PLAYER's own identity.
 * These bridge the OT/HT stamped onto an individual PKM, which can differ from the save's own
 * trainer once a Pokemon has been traded. */

int32_t pkhex_pkm_get_ot_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
void pkhex_pkm_set_ot_name(int64_t handle, const uint16_t *name, int32_t length);
int32_t pkhex_pkm_get_max_ot_name_length(int64_t handle);

/* 0 = male, 1 = female */
uint8_t pkhex_pkm_get_ot_gender(int64_t handle);
void pkhex_pkm_set_ot_gender(int64_t handle, uint8_t gender);

uint8_t pkhex_pkm_get_ot_friendship(int64_t handle);
void pkhex_pkm_set_ot_friendship(int64_t handle, uint8_t value);

uint16_t pkhex_pkm_get_tid16(int64_t handle);
void pkhex_pkm_set_tid16(int64_t handle, uint16_t tid);
uint16_t pkhex_pkm_get_sid16(int64_t handle);
void pkhex_pkm_set_sid16(int64_t handle, uint16_t sid);

/* Resets OT name/gender/TID/SID/language to the given save's own trainer identity — undoes trade
 * history stamped into the OT fields. Does not touch Handling Trainer fields or memories. */
void pkhex_pkm_reset_ot_to_save_trainer(int64_t pkm_handle, int64_t save_handle);

/* 1 if this PKM's format has any Handling Trainer concept at all (Gen 6+). Gate HT UI on this. */
uint8_t pkhex_pkm_get_supports_handling_trainer(int64_t handle);
/* 1 if this PKM currently has HT data set (i.e. has been traded at least once) — gate whether to
 * show the HT UI at all, separately from pkhex_pkm_get_current_handler (who holds it now). */
uint8_t pkhex_pkm_get_has_handling_trainer(int64_t handle);

int32_t pkhex_pkm_get_ht_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
void pkhex_pkm_set_ht_name(int64_t handle, const uint16_t *name, int32_t length);
uint8_t pkhex_pkm_get_ht_gender(int64_t handle);
void pkhex_pkm_set_ht_gender(int64_t handle, uint8_t gender);
uint8_t pkhex_pkm_get_ht_friendship(int64_t handle);
void pkhex_pkm_set_ht_friendship(int64_t handle, uint8_t value);

/* 0 = Original Trainer currently possesses it, 1 = Handling Trainer does (traded). */
uint8_t pkhex_pkm_get_current_handler(int64_t handle);
void pkhex_pkm_set_current_handler(int64_t handle, uint8_t value);

/* 1 if this PKM's format tracks OT/HT memories respectively (Gen 6+, except Let's Go Pikachu/Eevee
 * which drops the OT memory mechanic entirely — see PkmTrainerExports.cs remarks). Gate memory UI
 * on these rather than format >= 6 alone. */
uint8_t pkhex_pkm_get_supports_ot_memory(int64_t handle);
uint8_t pkhex_pkm_get_supports_ht_memory(int64_t handle);

uint8_t pkhex_pkm_get_ot_memory(int64_t handle);
void pkhex_pkm_set_ot_memory(int64_t handle, uint8_t value);
uint8_t pkhex_pkm_get_ot_memory_intensity(int64_t handle);
void pkhex_pkm_set_ot_memory_intensity(int64_t handle, uint8_t value);
uint8_t pkhex_pkm_get_ot_memory_feeling(int64_t handle);
void pkhex_pkm_set_ot_memory_feeling(int64_t handle, uint8_t value);
uint16_t pkhex_pkm_get_ot_memory_variable(int64_t handle);
void pkhex_pkm_set_ot_memory_variable(int64_t handle, uint16_t value);

uint8_t pkhex_pkm_get_ht_memory(int64_t handle);
void pkhex_pkm_set_ht_memory(int64_t handle, uint8_t value);
uint8_t pkhex_pkm_get_ht_memory_intensity(int64_t handle);
void pkhex_pkm_set_ht_memory_intensity(int64_t handle, uint8_t value);
uint8_t pkhex_pkm_get_ht_memory_feeling(int64_t handle);
void pkhex_pkm_set_ht_memory_feeling(int64_t handle, uint8_t value);
uint16_t pkhex_pkm_get_ht_memory_variable(int64_t handle);
void pkhex_pkm_set_ht_memory_variable(int64_t handle, uint16_t value);

/* Zeroes OT + HT memory fields. */
void pkhex_pkm_clear_memories(int64_t handle);

/* Valid Memory IDs for this PKM's context (0 = "None" always included), for building a memory
 * picker. Enumerate via pkhex_pkm_get_memory_id_count/get_memory_id_at_index(0..<count). */
int32_t pkhex_pkm_get_memory_id_count(int64_t handle);
uint8_t pkhex_pkm_get_memory_id_at_index(int64_t handle, int32_t index);

/* Raw sentence template for a memory id, e.g. "{0} met {1} {2}. {4} that {3}." — for a memory
 * picker's option label. Size-then-fill like other string exports. */
int32_t pkhex_memory_get_line(uint8_t memory_id, uint16_t *out_buffer, int32_t out_buffer_length);

/* What kind of value the memory's "variable" (TextVar) field means for the given memory id:
 * 0=None, 1=GeneralLocation, 2=SpecificLocation, 3=Species, 4=Move, 5=Item. Use to decide which
 * picker to show for the variable field. */
uint8_t pkhex_memory_get_variable_arg_type(int64_t handle, uint8_t memory_id);
/* Display name for a memory's variable value, resolved per pkhex_memory_get_variable_arg_type
 * (e.g. "Route 5" instead of a bare numeric TextVar). Size-then-fill like other string exports. */
int32_t pkhex_memory_get_variable_name(int64_t handle, uint8_t memory_id, uint16_t variable, uint16_t *out_buffer, int32_t out_buffer_length);

/* Lowest legal Intensity value for a given memory id. */
uint8_t pkhex_memory_get_minimum_intensity(int64_t handle, uint8_t memory_id);

/* Sets a known-legal "arrived via Link Trade" Handling Trainer memory — the same values
 * PKHeX.WinForms suggests when a trade is detected. Convenience "suggest a memory" action. */
void pkhex_pkm_set_trade_memory_ht(int64_t handle);

/* --- Trainer info (save file / player identity) --- */
int32_t pkhex_save_get_ot_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
void pkhex_save_set_ot_name(int64_t handle, const uint16_t *name, int32_t length);
int32_t pkhex_save_get_max_ot_name_length(int64_t handle);

uint16_t pkhex_save_get_tid(int64_t handle);
void pkhex_save_set_tid(int64_t handle, uint16_t tid);

uint16_t pkhex_save_get_sid(int64_t handle);
void pkhex_save_set_sid(int64_t handle, uint16_t sid);

/* 0 = male, 1 = female */
uint8_t pkhex_save_get_trainer_gender(int64_t handle);
void pkhex_save_set_trainer_gender(int64_t handle, uint8_t gender);

uint32_t pkhex_save_get_money(int64_t handle);
void pkhex_save_set_money(int64_t handle, uint32_t money);
int32_t pkhex_save_get_max_money(int64_t handle);

int32_t pkhex_save_get_played_hours(int64_t handle);
int32_t pkhex_save_get_played_minutes(int64_t handle);

/* --- Bag --- */
/* Bag handles are separate from the save handle: load a snapshot, edit its item slots, then
 * commit back into the save (which still needs pkhex_save_write to persist to disk). */
int64_t pkhex_bag_load(int64_t save_handle);
void pkhex_bag_close(int64_t handle);
int32_t pkhex_bag_commit(int64_t bag_handle, int64_t save_handle);

int32_t pkhex_bag_get_pouch_count(int64_t handle);
int32_t pkhex_bag_get_pouch_type(int64_t handle, int32_t pouch_index);
int32_t pkhex_bag_get_pouch_slot_count(int64_t handle, int32_t pouch_index);
/* 1 if this pouch has fewer slots than legal items (Gen 1-3 style free-form bag), 0 otherwise. */
int32_t pkhex_bag_get_pouch_is_cramped(int64_t handle, int32_t pouch_index);

/* The set of item IDs legal for a pouch, for building an "add item" picker. */
int32_t pkhex_bag_get_pouch_legal_item_count(int64_t handle, int32_t pouch_index);
int32_t pkhex_bag_get_pouch_legal_item(int64_t handle, int32_t pouch_index, int32_t item_list_index);

int32_t pkhex_bag_get_item_index(int64_t handle, int32_t pouch_index, int32_t slot);
int32_t pkhex_bag_get_item_count(int64_t handle, int32_t pouch_index, int32_t slot);
int32_t pkhex_bag_set_item(int64_t handle, int32_t pouch_index, int32_t slot, int32_t item_index, int32_t count);

/* Finds the first empty slot in the pouch and assigns it to item_index/count. Returns the slot
 * index used, or -1 if the pouch is full. */
int32_t pkhex_bag_add_item(int64_t handle, int32_t pouch_index, int32_t item_index, int32_t count);

/* Display name for an item index as stored in THIS bag's pouches. Use this instead of
 * pkhex_item_get_name for any item id that came from this bag (pkhex_bag_get_item_index,
 * pkhex_bag_get_pouch_legal_item) — Gen 1-3 saves store item ids in their own legacy numbering,
 * not the shared/modern id space, so pkhex_item_get_name gives the wrong name for those. */
int32_t pkhex_bag_get_item_name(int64_t bag_handle, uint16_t item, uint16_t *out_buffer, int32_t out_buffer_length);

#endif /* PKHEX_NATIVE_H */
