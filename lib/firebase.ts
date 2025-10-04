// lib/firebase.ts
import { initializeApp } from 'firebase/app';
import {
  initializeAuth,
  getReactNativePersistence,
  browserLocalPersistence
} from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';


const firebaseConfig = {
  apiKey: "AIzaSyBMCQA69Vx8ydgteqEnwlbv3WqInxakiZo",
  authDomain: "irs-notice-tracker.firebaseapp.com",
  projectId: "irs-notice-tracker",
  storageBucket: "irs-notice-tracker.firebasestorage.app",
  messagingSenderId: "753188109781",
  appId: "1:753188109781:web:14275df1d88b534288915c"
};

const app = initializeApp(firebaseConfig);

// Initialize Auth with platform-specific persistence
export const auth = initializeAuth(app, {
  persistence: Platform.OS === 'web'
    ? browserLocalPersistence
    : getReactNativePersistence(AsyncStorage)
});

// Initialize Firestore
export const db = getFirestore(app);


export default app;