/**
 * Created by weijian on 2016/10/24.
 */
import {Injectable} from '@angular/core';
import {remote} from 'electron';
import * as path from 'path';

export interface Library {
  'default': boolean;
  path: string;
}

@Injectable()
export class SettingsService {

  static SETTING_LIBRARY = 'library';
  static defaultLibraries = [
    {
      'default': true,
      path: path.join(remote.app.getPath('appData'), 'MyCardLibrary')
    },
  ];
  static SETTING_LOCALE = 'locale';
  static defaultLocale = remote.app.getLocale();

  locale: string;
  libraries: Library[];


  getLibraries () {
    if (!this.libraries) {
      const data = localStorage.getItem(SettingsService.SETTING_LIBRARY);
      if (!data) {
        this.libraries = SettingsService.defaultLibraries;
        localStorage.setItem(SettingsService.SETTING_LIBRARY,
          JSON.stringify(SettingsService.defaultLibraries));
      } else {
        this.libraries = JSON.parse(data);
      }
    }
    return this.libraries;
  }

  addLibrary (libraryPath: string, isDefault: boolean) {

    const libraries = this.getLibraries();
    if (isDefault) {
      libraries.forEach((l) => {
        l.default = false;
      });
    }
    libraries.push({'default': isDefault, path: libraryPath});
    this.libraries = libraries;
    localStorage.setItem(SettingsService.SETTING_LIBRARY, JSON.stringify(libraries));
  }

  setDefaultLibrary (library: Library) {
    const libraries = this.getLibraries();
    libraries.forEach((l) => {
      l.default = library.path === l.path;
    });
    this.libraries = libraries;
    localStorage.setItem(SettingsService.SETTING_LIBRARY, JSON.stringify(libraries));
  }

  getDefaultLibrary (): Library {
    if (!this.libraries) {
      this.getLibraries();
    }
    const result = this.libraries.find((item) => item.default === true);
    if (result) {
      return result;
    } else {
      throw new Error(('no default library found'));
    }
  }

  getLocale (): string {
    if (!this.locale) {
      const locale = localStorage.getItem(SettingsService.SETTING_LOCALE);
      if (!locale) {
        this.locale = SettingsService.defaultLocale;
        localStorage.setItem(SettingsService.SETTING_LOCALE, SettingsService.defaultLocale);
      } else {
        this.locale = locale;
      }
    }
    return this.locale;
  }

  setLocale (locale: string) {
    this.locale = locale;
    localStorage.setItem(SettingsService.SETTING_LOCALE, locale);
  }
}
