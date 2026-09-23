-- CreateTable
CREATE TABLE "personnel" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "full_name" TEXT NOT NULL,
    "department" TEXT,
    "contact_email" TEXT,
    "notes" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "workstations" (
    "workstation_tag" TEXT NOT NULL PRIMARY KEY,
    "user_name" TEXT,
    "personnel_id" TEXT,
    "device_type" TEXT,
    "motherboard" TEXT,
    "processor_gen" TEXT,
    "ram" TEXT,
    "ssd" TEXT,
    "hdd" TEXT,
    "gpu" TEXT,
    "status" TEXT NOT NULL DEFAULT 'IN_STORE',
    "assigned_date" DATETIME,
    "pdf_file" TEXT,
    "notes" TEXT,
    "custom_fields" TEXT,
    CONSTRAINT "workstations_personnel_id_fkey" FOREIGN KEY ("personnel_id") REFERENCES "personnel" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "peripherals" (
    "peripheral_tag" TEXT NOT NULL PRIMARY KEY,
    "category" TEXT,
    "model_specs" TEXT,
    "workstation_tag" TEXT,
    "personnel_id" TEXT,
    "status" TEXT NOT NULL DEFAULT 'IN_STORE',
    "purchase_date" DATETIME,
    "warranty_expiry" DATETIME,
    "brand_manufacturer" TEXT,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "storage_capacity" TEXT,
    "gpu_specs" TEXT,
    "custom_fields" TEXT,
    CONSTRAINT "peripherals_personnel_id_fkey" FOREIGN KEY ("personnel_id") REFERENCES "personnel" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "peripherals_workstation_tag_fkey" FOREIGN KEY ("workstation_tag") REFERENCES "workstations" ("workstation_tag") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "users" (
    "email" TEXT NOT NULL PRIMARY KEY,
    "full_name" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'VIEWER',
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "password_hash" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "custom_field_definitions" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "field_type" TEXT NOT NULL,
    "options" TEXT,
    "required" BOOLEAN NOT NULL DEFAULT false,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "app_settings" (
    "key" TEXT NOT NULL PRIMARY KEY,
    "value" TEXT NOT NULL,
    "updated_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "log_id" TEXT NOT NULL PRIMARY KEY,
    "timestamp" DATETIME NOT NULL,
    "user_email" TEXT,
    "asset_tag" TEXT,
    "action_taken" TEXT NOT NULL
);

-- CreateIndex
CREATE INDEX "peripherals_personnel_id_idx" ON "peripherals"("personnel_id");

-- CreateIndex
CREATE UNIQUE INDEX "custom_field_definitions_name_key" ON "custom_field_definitions"("name");
