import { NativeEventEmitter } from 'react-native';
// Import directly from the module, NOT from the "../utils" barrel.
//
// The barrel (utils/index.ts) re-exports ./EventEmitter BEFORE ./NativeModules.
// Importing HyperPaySDK back through the barrel from here creates a require
// cycle: loading the barrel starts with this file, which asks the barrel for
// HyperPaySDK before the barrel has evaluated ./NativeModules. Metro (like
// Node) returns the partially-populated exports object, so HyperPaySDK is
// undefined and this line throws
//
//   TypeError: Cannot read property 'HyperPaySDK' of undefined
//
// at import time — before React renders, taking down any app that imports this
// package at module scope. Depending on the module directly breaks the cycle.
import { HyperPaySDK } from './NativeModules';

export const eventEmitter = new NativeEventEmitter(HyperPaySDK);
