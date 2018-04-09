ALTER TABLE ONLY documentscontent drop constraint documentscontent_hostid_key;
ALTER TABLE ONLY documentscontent ADD CONSTRAINT documentscontent_hostid_key UNIQUE (hostid,language,title);
