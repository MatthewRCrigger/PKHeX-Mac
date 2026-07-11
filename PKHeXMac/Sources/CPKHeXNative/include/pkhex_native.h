#ifndef PKHEX_NATIVE_H
#define PKHEX_NATIVE_H

#include <stdint.h>

/* C ABI surface exported by PKHeX.Native (see PKHeX.Native/*.cs). All handles are opaque
 * non-zero int64 IDs into a managed registry; 0 means "invalid/not found". */

/* --- Save lifecycle --- */
int64_t pkhex_save_load(const uint8_t *data, int32_t length);
void pkhex_save_close(int64_t handle);
int32_t pkhex_save_write(int64_t handle, uint8_t *out_buffer, int32_t out_buffer_length);

int32_t pkhex_save_get_box_count(int64_t handle);
int32_t pkhex_save_get_box_slot_count(int64_t handle);
uint8_t pkhex_save_get_generation(int64_t handle);

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

int32_t pkhex_save_get_party_count(int64_t handle);
int64_t pkhex_save_get_party_slot(int64_t handle, int32_t index);
int32_t pkhex_save_set_party_slot(int64_t save_handle, int64_t pkm_handle, int32_t index);

/* --- PKM lifecycle & fields --- */
void pkhex_pkm_close(int64_t handle);

uint16_t pkhex_pkm_get_species(int64_t handle);
void pkhex_pkm_set_species(int64_t handle, uint16_t species);

uint8_t pkhex_pkm_get_format(int64_t handle);

uint8_t pkhex_pkm_get_level(int64_t handle);
void pkhex_pkm_set_level(int64_t handle, uint8_t level);

uint8_t pkhex_pkm_get_nature(int64_t handle);
void pkhex_pkm_set_nature(int64_t handle, uint8_t nature);

uint8_t pkhex_pkm_get_gender(int64_t handle);
void pkhex_pkm_set_gender(int64_t handle, uint8_t gender);

uint8_t pkhex_pkm_get_is_shiny(int64_t handle);

uint16_t pkhex_pkm_get_held_item(int64_t handle);
void pkhex_pkm_set_held_item(int64_t handle, uint16_t item);

uint16_t pkhex_pkm_get_ability(int64_t handle);

/* Type IDs (see pkhex_type_get_name); Type2 equals Type1 for single-type species. */
uint8_t pkhex_pkm_get_type1(int64_t handle);
uint8_t pkhex_pkm_get_type2(int64_t handle);

uint16_t pkhex_pkm_get_move(int64_t handle, int32_t index);
void pkhex_pkm_set_move(int64_t handle, int32_t index, uint16_t move);

int32_t pkhex_pkm_get_iv(int64_t handle, int32_t stat);
void pkhex_pkm_set_iv(int64_t handle, int32_t stat, int32_t value);

int32_t pkhex_pkm_get_ev(int64_t handle, int32_t stat);
void pkhex_pkm_set_ev(int64_t handle, int32_t stat, int32_t value);

int32_t pkhex_pkm_get_move_pp(int64_t handle, int32_t index);
int32_t pkhex_pkm_get_move_pp_max(int64_t handle, int32_t index);

/* UTF-16 code units; call once with NULL buffer to size, again to fill. */
int32_t pkhex_pkm_get_nickname(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
void pkhex_pkm_set_nickname(int64_t handle, const uint16_t *name, int32_t length);

int32_t pkhex_pkm_get_sprite_file_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);

int32_t pkhex_pkm_get_max_nickname_length(int64_t handle);

/* --- Name lookups (current display language; UTF-16, size-then-fill like above) --- */
int32_t pkhex_species_get_name(uint16_t species, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_move_get_name(uint16_t move, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_nature_get_name(uint8_t nature, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_item_get_name(uint16_t item, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_type_get_name(uint8_t type, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_ability_get_name(uint16_t ability, uint16_t *out_buffer, int32_t out_buffer_length);

/* --- Legality --- */
int32_t pkhex_pkm_is_legal(int64_t handle);
int32_t pkhex_pkm_get_legality_report(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length, uint8_t verbose);

/* Human-readable legality reasons, one per line, empty if legal (verbose off; same text as
 * pkhex_pkm_get_legality_report(verbose:0)). Intended for showing just the first line in a UI banner. */
int32_t pkhex_pkm_get_legality_lines(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);

/* Highest move ID valid for this PKM's format, for a fallback "all moves" picker. */
uint16_t pkhex_pkm_get_max_move_id(int64_t handle);

/* The move IDs this PKM can currently legally learn, for building a move picker. */
int32_t pkhex_pkm_get_legal_move_count(int64_t handle);
uint16_t pkhex_pkm_get_legal_move(int64_t handle, int32_t move_list_index);

/* --- Trainer info --- */
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

#endif /* PKHEX_NATIVE_H */
