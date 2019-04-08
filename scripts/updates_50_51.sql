ALTER TABLE ONLY documentscontent drop constraint documentscontent_hostid_key;
ALTER TABLE ONLY documentscontent ADD CONSTRAINT documentscontent_hostid_key UNIQUE (hostid,language,title);
ALTER TABLE ONLY documents ADD (published       timestamp       default null);
