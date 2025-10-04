// app/_layout.tsx
// Root layout with authentication handling

import { Stack, useRouter, useSegments } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { AuthProvider, useAuth } from '../contexts/AuthContext';

function RootLayoutNav() {
  const { user, loading } = useAuth();
  const segments = useSegments();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;

    const inAuthGroup = segments[0] === '(auth)';

    if (!user && !inAuthGroup) {
      // Redirect to login if not authenticated
      router.replace('/(auth)/login');
    } else if (user && inAuthGroup) {
      // Redirect to dashboard if authenticated and trying to access auth screens
      router.replace('/(tabs)/dashboard');
    }
  }, [user, loading, segments]);

  if (loading) {
    // You can show a splash screen here
    return null;
  }

  return (
    <>
      <StatusBar style="light" />
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(auth)" options={{ headerShown: false }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen 
          name="client/[id]" 
          options={{ 
            presentation: 'modal',
            headerShown: true,
            title: 'Client Details'
          }} 
        />
        <Stack.Screen 
          name="client/add" 
          options={{ 
            presentation: 'modal',
            headerShown: true,
            title: 'Add Client'
          }} 
        />
        <Stack.Screen 
          name="notice/[id]" 
          options={{ 
            presentation: 'modal',
            headerShown: true,
            title: 'Notice Details'
          }} 
        />
        <Stack.Screen 
          name="notice/add" 
          options={{ 
            presentation: 'modal',
            headerShown: true,
            title: 'Add Notice'
          }} 
        />
        <Stack.Screen 
          name="response/[id]" 
          options={{ 
            presentation: 'modal',
            headerShown: true,
            title: 'Response Details'
          }} 
        />
        <Stack.Screen 
          name="response/add" 
          options={{ 
            presentation: 'modal',
            headerShown: true,
            title: 'Log Response'
          }} 
        />
      </Stack>
    </>
  );
}

export default function RootLayout() {
  return (
    <AuthProvider>
      <RootLayoutNav />
    </AuthProvider>
  );
}