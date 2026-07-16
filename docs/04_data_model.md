# 04. データモデル

以下は実装言語に依存しない論理モデル。

## Project

- `id`
- `title`
- `category`
- `status`
- `createdAt`
- `updatedAt`
- `advancedUnlocked`
- `archivedAt`

## Requirement

- `id`
- `projectId`
- `categoryCode`
- `requirementType`
- `specification`
- `quantity`
- `unit`
- `note`

`requirementType`:

- required
- optional
- excluded
- unset

## Vendor

- `id`
- `projectId`
- `displayName`
- `contactNote`
- `createdAt`

## QuoteRevision

- `id`
- `vendorId`
- `revisionNumber`
- `quoteDate`
- `validUntil`
- `subtotal`
- `discount`
- `tax`
- `total`
- `paymentTerms`
- `warranty`
- `constructionPeriod`
- `createdAt`

## DocumentPage

- `id`
- `quoteRevisionId`
- `pageNumber`
- `localFilePath`
- `pageType`
- `rotation`
- `width`
- `height`
- `ocrStatus`

## OCRBlock

- `id`
- `documentPageId`
- `text`
- `boundingBox`
- `confidence`
- `blockOrder`

## RawLineItem

- `id`
- `quoteRevisionId`
- `originalText`
- `description`
- `quantity`
- `unit`
- `unitPrice`
- `amount`
- `pageNumber`
- `boundingBox`
- `confidence`
- `isLumpSum`

## NormalizedLineItem

- `id`
- `rawLineItemId`
- `categoryCode`
- `inclusionStatus`
- `normalizationConfidence`
- `userConfirmed`
- `specification`
- `comparisonGroupId`

## Clarification

- `id`
- `projectId`
- `vendorId`
- `quoteRevisionId`
- `sourceLineItemId`
- `question`
- `status`
- `answer`
- `createdAt`
- `resolvedAt`

`status`:

- open
- sent
- answered
- resolved
- dismissed

## UnlockEntitlement

- `id`
- `projectId`
- `unlockType`
- `source`
- `grantedAt`

`source`:

- reward_ad
- purchase
- promotional
- debug

## AuditCorrection

ユーザー修正をローカルで記録する。

- `id`
- `entityType`
- `entityId`
- `fieldName`
- `beforeValue`
- `afterValue`
- `correctedAt`

クラウドへ送らず、再解析や差分表示に利用する。
