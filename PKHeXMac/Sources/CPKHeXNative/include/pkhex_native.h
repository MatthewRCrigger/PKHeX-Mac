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

/* --- Name lookups (current display language; UTF-16, size-then-fill like above) --- */
int32_t pkhex_species_get_name(uint16_t species, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_move_get_name(uint16_t move, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_nature_get_name(uint8_t nature, uint16_t *out_buffer, int32_t out_buffer_length);
int32_t pkhex_item_get_name(uint16_t item, uint16_t *out_buffer, int32_t out_buffer_length);

/* --- Legality --- */
int32_t pkhex_pkm_is_legal(int64_t handle);
int32_t pkhex_pkm_get_legality_report(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length, uint8_t verbose);

/* --- Trainer info --- */
int32_t pkhex_save_get_ot_name(int64_t handle, uint16_t *out_buffer, int32_t out_buffer_length);
void pkhex_save_set_ot_name(int64_t handle, const uint16_t *name, int32_t length);

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

int32_t pkhex_bag_get_item_index(int64_t handle, int32_t pouch_index, int32_t slot);
int32_t pkhex_bag_get_item_count(int64_t handle, int32_t pouch_index, int32_t slot);
int32_t pkhex_bag_set_item(int64_t handle, int32_t pouch_index, int32_t slot, int32_t item_index, int32_t count);

#endif /* PKHEX_NATIVE_H */
