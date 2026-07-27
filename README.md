# Nus·Nus (نسنس)

A premium, localized expense splitting app built with Flutter and Firebase. "Nus·Nus" (meaning "half-half") allows users to track shared tabs, calculate complex splits using AI, and manage debts across multiple groups with ease.

## Key Features
- **Dynamic Currency**: Per-group currency support (AED, USD, INR, etc.).
- **Nus Ai**: Multimodal bill parsing using Gemini 1.5 Flash.
- **Clear Views**: Ticket-style activity feed and aggregated "People" dashboard.
- **Secure Settlements**: Creditor-only settlement confirmation.

## Security Model

The following rules are defined in `firestore.rules` and enforced on the server:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only manage their own profile.
    match /users/{uid} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null && request.auth.uid == uid;
    }

    // Groups are accessible by members and owned by creators.
    match /groups/{groupId} {
      allow read: if request.auth != null && request.auth.uid in resource.data.memberUids;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.ownerId;
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.ownerId;

      // Expenses within a group.
      match /expenses/{expenseId} {
        allow read: if request.auth != null && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.memberUids;
        allow create: if request.auth != null && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.memberUids && request.resource.data.addedBy == request.auth.uid;
        
        // Only the original creator of a split can edit or delete it.
        allow update, delete: if request.auth != null && request.auth.uid == resource.data.addedBy;
      }
    }
  }
}
```
