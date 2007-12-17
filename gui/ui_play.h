//------------------------------------------------------------------------
//  Play Settings
//------------------------------------------------------------------------
//
//  Oblige Level Maker (C) 2006,2007 Andrew Apted
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//------------------------------------------------------------------------

#ifndef __UI_PLAY_H__
#define __UI_PLAY_H__

class UI_Play : public Fl_Group
{
public: // private:

  UI_RChoice *mons;
  UI_RChoice *puzzles;
  UI_RChoice *traps;

  UI_RChoice *health;
  UI_RChoice *ammo;

public:
  UI_Play(int x, int y, int w, int h, const char *label = NULL);
  virtual ~UI_Play();

public:

  void Locked(bool value);
  
  const char *GetAllValues();
  // return a string containing all the values from this panel,
  // in a form suitable for the Config file.
  // The string should NOT be freed.

  bool ParseValue(const char *key, const char *value);
  // parse the name and store the value in the appropriate
  // widget.  Returns false if the key was unknown or the
  // value was invalid.

  const char *get_Monsters();
  const char *get_Puzzles();
  const char *get_Traps();
  const char *get_Health();
  const char *get_Ammo();

  bool set_Monsters(const char *str);
  bool set_Puzzles (const char *str);
  bool set_Traps   (const char *str);
  bool set_Health  (const char *str);
  bool set_Ammo    (const char *str);

private:
  int FindSym(const char *str);

  void setup_Monsters();
  void setup_Puzzles ();
  void setup_Traps   ();
  void setup_Health  ();
  void setup_Ammo    ();

///---  void UpdateLabels(const char *game, const char *mode);

  static void notify_Mode(const char *name, void *priv_dat);

  static void callback_Monsters(Fl_Widget *, void*);
  static void callback_Puzzles (Fl_Widget *, void*);
  static void callback_Traps   (Fl_Widget *, void*);
  static void callback_Health  (Fl_Widget *, void*);
  static void callback_Ammo    (Fl_Widget *, void*);

  static const char * monster_syms[];
  static const char * trap_syms[];
  static const char * health_syms[];
};

#endif /* __UI_PLAY_H__ */
